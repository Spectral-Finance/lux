defmodule Lux.Lenses.NftCollectionStatsLens do
  @moduledoc """
  Lens for fetching NFT collection statistics from Reservoir.
  Supports OpenSea, Blur, X2Y2 aggregated data.

  ## Example

  ```
  alias Lux.Lenses.NftCollectionStatsLens

  # Fetch stats for a collection
  NftCollectionStatsLens.focus(%{
    collection: "0x8d04a8c79ceb0889bdd12acdf3fa9d207ed3ff63"
  })
  ```
  """

  use Lux.Lens,
    name: "NFT Collection Stats",
    description: "Fetches collection statistics including floor price, volume, and trait data",
    url: "https://api.reservoir.tools/collections/v7",
    method: :get,
    headers: [{"accept", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        collection: %{
          type: :string,
          description: "Collection contract address"
        }
      },
      required: ["collection"]
    }

  def add_api_key(lens) do
    case Lux.Config.reservoir_api_key() do
      nil -> lens
      key -> %{lens | headers: lens.headers ++ [{"x-api-key", key}]}
    end
  end

  def before_focus(params) do
    Map.put(%{}, :id, params.collection)
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(%{"collections" => [collection | _]}) do
    stats = %{
      name: collection["name"],
      symbol: collection["symbol"],
      floor_price: get_in(collection, ["floorAsk", "price", "amount", "native"]),
      volume_all_time: collection["volume"]["allTime"],
      volume_1day: collection["volume"]["1day"],
      volume_7day: collection["volume"]["7day"],
      token_count: collection["tokenCount"],
      owner_count: collection["ownerCount"],
      top_bid: get_in(collection, ["topBid", "price", "amount", "native"]),
      supply: collection["supply"]
    }

    {:ok, %{collection_stats: stats}}
  end

  @impl true
  def after_focus(%{"collections" => []}) do
    {:error, "Collection not found"}
  end

  @impl true
  def after_focus(%{"message" => message}) do
    {:error, message}
  end

  @impl true
  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end
