defmodule Lux.Lenses.X2Y2.Collections.GetSales do
  @moduledoc """
  A lens for retrieving recent NFT sales from the X2Y2 marketplace API.

  This lens provides:
  - Recent sale events with prices
  - Buyer and seller addresses
  - NFT token IDs
  - Transaction hashes for on-chain verification
  - Pagination support

  ## Authentication

  Optional API key via `X-API-Key` header. Configure in application config:

      config :lux, :api_keys, x2y2: "your_x2y2_api_key"

  ## Examples

      iex> GetSales.focus(%{
      ...>   contract: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
      ...>   limit: 20
      ...> })
      {:ok, %{
        sales: [
          %{
            token_id: "1234",
            price: 10.2,
            price_currency: "ETH",
            seller: "0x...",
            buyer: "0x...",
            timestamp: 1705315200,
            transaction_hash: "0x..."
          }
        ],
        next_cursor: "cursor_xyz",
        count: 20
      }}
  """

  alias Lux.Integrations.X2Y2

  use Lux.Lens,
    name: "Get X2Y2 Collection Sales",
    description: "Retrieves recent sale events for an NFT collection from X2Y2 marketplace",
    url: "https://api.x2y2.io/v1/events",
    method: :get,
    headers: X2Y2.headers(),
    auth: X2Y2.auth(),
    schema: %{
      type: :object,
      properties: %{
        contract: %{
          type: :string,
          description: "The NFT contract address",
          pattern: "^0x[0-9a-fA-F]{40}$"
        },
        limit: %{
          type: :integer,
          description: "Number of results to return (1-100, default 20)",
          minimum: 1,
          maximum: 100,
          default: 20
        },
        cursor: %{
          type: :string,
          description: "Pagination cursor from previous response"
        }
      },
      required: ["contract"]
    }

  @doc """
  Transforms the X2Y2 events API response into a simplified sale format.
  """
  @impl true
  def after_focus(%{"data" => data} = response) when is_list(data) do
    sales = data
    |> Enum.filter(&(&1["type"] == "sale"))
    |> Enum.map(&format_sale/1)

    result = %{
      sales: sales,
      count: length(sales),
      next_cursor: response["next"]
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

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp format_sale(event) do
    order = event["order"] || %{}
    token = event["token"] || %{}

    %{
      token_id: to_string(token["token_id"] || ""),
      price: parse_wei(order["price"]),
      price_currency: "ETH",
      seller: event["from_address"],
      buyer: event["to_address"],
      timestamp: event["created_at"],
      transaction_hash: event["tx"],
      marketplace: "x2y2"
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end

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
