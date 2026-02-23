defmodule Lux.Lenses.OpenSea.Collections.GetMarketTrends do
  @moduledoc """
  A lens for retrieving NFT market trend data across top collections from the OpenSea API v2.

  This lens provides:
  - Top collections by volume, floor price, or sales
  - Time-based volume trends (1d, 7d, 30d)
  - Floor price movement tracking
  - Market momentum signals

  ## Authentication

  Uses optional API key via `x-api-key` header. Configure in application config:

      config :lux, :api_keys, opensea: "your_api_key"

  ## Examples

      iex> GetMarketTrends.focus(%{
      ...>   sort_by: "one_day_volume",
      ...>   limit: 10
      ...> })
      {:ok, %{
        collections: [
          %{
            collection: "boredapeyachtclub",
            name: "Bored Ape Yacht Club",
            floor_price: 10.5,
            one_day_volume: 234.56,
            one_day_change: 12.3,
            seven_day_volume: 1234.78,
            num_owners: 5432
          }
        ],
        sort_by: "one_day_volume",
        count: 10
      }}
  """

  alias Lux.Integrations.OpenSea

  use Lux.Lens,
    name: "Get NFT Market Trends",
    description: "Retrieves trending NFT collections ranked by volume, sales, or floor price",
    url: "https://api.opensea.io/api/v2/collections",
    method: :get,
    headers: OpenSea.headers(),
    auth: OpenSea.auth(),
    schema: %{
      type: :object,
      properties: %{
        sort_by: %{
          type: :string,
          description: "Sort field for ranking collections",
          enum: ["one_day_volume", "seven_day_volume", "thirty_day_volume", "total_volume",
                 "one_day_sales", "seven_day_sales", "one_day_average_price", "floor_price",
                 "market_cap"],
          default: "one_day_volume"
        },
        sort_ascending: %{
          type: :boolean,
          description: "Sort direction (false = descending, default)",
          default: false
        },
        limit: %{
          type: :integer,
          description: "Number of collections to return (1-100, default 20)",
          minimum: 1,
          maximum: 100,
          default: 20
        },
        chain: %{
          type: :string,
          description: "Filter by blockchain (e.g. 'ethereum', 'base', 'matic')"
        },
        next: %{
          type: :string,
          description: "Pagination cursor"
        }
      }
    }

  @doc """
  Transforms the OpenSea collections list response into trend data.
  """
  @impl true
  def after_focus(%{"collections" => collections} = data) do
    trends = Enum.map(collections, &format_collection_trend/1)

    result = %{
      collections: trends,
      count: length(trends),
      next_cursor: data["next"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def after_focus(%{"errors" => errors}) when is_list(errors) do
    {:error, %{errors: errors}}
  end

  def after_focus(%{"detail" => detail}) do
    {:error, %{detail: detail}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp format_collection_trend(collection) do
    stats = collection["stats"] || %{}

    %{
      collection: collection["collection"],
      name: collection["name"],
      image_url: collection["image_url"],
      chain: collection["primary_asset_contracts"] |> get_chain(),
      floor_price: stats["floor_price"],
      floor_price_currency: stats["floor_price_symbol"] || "ETH",
      one_day_volume: stats["one_day_volume"],
      one_day_sales: stats["one_day_sales"],
      one_day_average_price: stats["one_day_average_price"],
      seven_day_volume: stats["seven_day_volume"],
      seven_day_sales: stats["seven_day_sales"],
      thirty_day_volume: stats["thirty_day_volume"],
      thirty_day_sales: stats["thirty_day_sales"],
      total_volume: stats["total_volume"],
      total_sales: stats["total_sales"],
      num_owners: stats["num_owners"],
      total_supply: stats["total_supply"],
      market_cap: stats["market_cap"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp get_chain(nil), do: nil
  defp get_chain([]), do: nil
  defp get_chain([contract | _]), do: contract["chain"]
  defp get_chain(_), do: nil
end
