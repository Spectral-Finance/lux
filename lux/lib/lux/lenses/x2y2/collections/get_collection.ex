defmodule Lux.Lenses.X2Y2.Collections.GetCollection do
  @moduledoc """
  A lens for retrieving NFT collection statistics from the X2Y2 marketplace API.

  X2Y2 provides NFT marketplace data as an alternative to OpenSea and Blur,
  with competitive pricing and analytics for Ethereum collections.

  This lens provides:
  - Floor price and volume statistics
  - Royalty information
  - Owner and supply counts
  - Market trend data

  ## Authentication

  Optional API key via `X-API-Key` header. Configure in application config:

      config :lux, :api_keys, x2y2: "your_x2y2_api_key"

  ## Examples

      iex> GetCollection.focus(%{
      ...>   contract: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
      ...> })
      {:ok, %{
        contract: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
        name: "Bored Ape Yacht Club",
        floor_price: 10.1,
        floor_price_currency: "ETH",
        volume_24h: 145.3,
        total_volume: 523400.0,
        num_owners: 5430,
        total_supply: 10000
      }}
  """

  alias Lux.Integrations.X2Y2

  use Lux.Lens,
    name: "Get NFT Collection from X2Y2",
    description: "Retrieves collection floor price, volume, and statistics from X2Y2 marketplace",
    url: "https://api.x2y2.io/v1/contracts/:contract/stats",
    method: :get,
    headers: X2Y2.headers(),
    auth: X2Y2.auth(),
    schema: %{
      type: :object,
      properties: %{
        contract: %{
          type: :string,
          description: "The NFT contract address on Ethereum",
          pattern: "^0x[0-9a-fA-F]{40}$"
        }
      },
      required: ["contract"]
    }

  @doc """
  Transforms the X2Y2 API response into a simplified format.
  """
  @impl true
  def after_focus(%{"data" => data}) when is_map(data) do
    result = %{
      contract: data["contract"],
      name: data["name"],
      image_url: data["image"],
      description: data["description"],
      floor_price: parse_wei(data["floor_price"]),
      floor_price_currency: "ETH",
      volume_24h: parse_wei(data["volume_24h"]),
      volume_7d: parse_wei(data["volume_7d"]),
      volume_30d: parse_wei(data["volume_30d"]),
      total_volume: parse_wei(data["volume_total"]),
      num_owners: data["owners"],
      total_supply: data["total"],
      listed_count: data["listed"],
      sales_24h: data["sales_24h"],
      royalty_bps: data["royalty"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def after_focus(%{"errors" => errors}) when is_list(errors) do
    {:error, %{errors: errors}}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{message: message}}
  end

  def after_focus(%{"error" => error}) do
    {:error, %{error: error}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  # X2Y2 returns prices in wei (1e18)
  defp parse_wei(nil), do: nil
  defp parse_wei(0), do: 0.0
  defp parse_wei(n) when is_integer(n), do: n / 1_000_000_000_000_000_000
  defp parse_wei(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, ""} -> i / 1_000_000_000_000_000_000
      _ ->
        case Float.parse(s) do
          {f, ""} -> f
          _ -> nil
        end
    end
  end
  defp parse_wei(f) when is_float(f), do: f
end
