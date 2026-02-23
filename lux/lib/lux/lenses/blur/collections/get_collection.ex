defmodule Lux.Lenses.Blur.Collections.GetCollection do
  @moduledoc """
  A lens for retrieving NFT collection statistics from the Blur marketplace API.

  This lens provides cross-marketplace data from Blur including:
  - Floor prices (best ask)
  - Bid statistics
  - 24-hour volume and sales
  - Total listings count

  ## Examples

      iex> GetCollection.focus(%{
      ...>   contract_address: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
      ...> })
      {:ok, %{
        contract_address: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
        name: "Bored Ape Yacht Club",
        floor_price: 10.2,
        floor_price_currency: "ETH",
        num_listed: 432,
        volume_24h: 156.7,
        sales_24h: 14
      }}
  """

  alias Lux.Integrations.Blur

  use Lux.Lens,
    name: "Get NFT Collection from Blur",
    description: "Retrieves collection floor price, volume, and market stats from Blur marketplace",
    url: "https://core-api.prod.blur.io/v1/collections/:contract_address",
    method: :get,
    headers: Blur.headers(),
    auth: Blur.auth(),
    schema: %{
      type: :object,
      properties: %{
        contract_address: %{
          type: :string,
          description: "The contract address of the NFT collection",
          pattern: "^0x[0-9a-fA-F]{40}$"
        }
      },
      required: ["contract_address"]
    }

  @doc """
  Transforms the Blur API response into a simplified format.
  """
  @impl true
  def after_focus(%{"collection" => collection}) do
    best_ask = collection["floorAsk"] || collection["bestAsk"] || %{}
    stats = collection["stats"] || %{}

    result = %{
      contract_address: collection["contractAddress"],
      name: collection["name"],
      image_url: collection["imageUrl"],
      description: collection["description"],
      floor_price: parse_number(best_ask["amount"] || best_ask["price"]),
      floor_price_currency: best_ask["currency"] || "ETH",
      num_listed: collection["bestAsk"] && collection["listedCount"] || stats["numListed"],
      total_supply: collection["totalSupply"] || stats["totalSupply"],
      volume_24h: parse_number(stats["volume24h"] || stats["totalVolume24h"]),
      sales_24h: stats["sales24h"],
      volume_7d: parse_number(stats["volume7d"]),
      volume_30d: parse_number(stats["volume30d"]),
      num_owners: stats["numOwners"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
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

  defp parse_number(nil), do: nil
  defp parse_number(n) when is_number(n), do: n
  defp parse_number(s) when is_binary(s) do
    case Float.parse(s) do
      {f, ""} -> f
      _ ->
        case Integer.parse(s) do
          {i, ""} -> i
          _ -> nil
        end
    end
  end
end
