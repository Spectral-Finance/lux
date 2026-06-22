defmodule Lux.Lenses.NftSalesLens do
  @moduledoc """
  Lens for fetching NFT sales data from Reservoir.
  Monitors sales across major marketplaces.

  ## Example

  ```
  alias Lux.Lenses.NftSalesLens

  # Fetch recent sales for a collection
  NftSalesLens.focus(%{
    collection: "0x8d04a8c79ceb0889bdd12acdf3fa9d207ed3ff63",
    limit: 10
  })
  ```
  """

  use Lux.Lens,
    name: "NFT Sales Data",
    description: "Fetches recent sales for an NFT collection across marketplaces",
    url: "https://api.reservoir.tools/sales/v6",
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
        },
        limit: %{
          type: :integer,
          description: "Number of sales to return",
          default: 50
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
    %{
      collection: params.collection,
      limit: Map.get(params, :limit, 50)
    }
  end

  @impl true
  def after_focus(%{"sales" => sales}) when is_list(sales) do
    transformed_sales =
      Enum.map(sales, fn sale ->
        %{
          id: sale["id"],
          token_id: sale["token"]["tokenId"],
          order_source: sale["orderSource"],
          price_eth: get_in(sale, ["price", "amount", "native"]),
          price_usd: get_in(sale, ["price", "amount", "usd"]),
          buyer: sale["to"],
          seller: sale["from"],
          timestamp: sale["timestamp"],
          marketplace: sale["fillSource"] || sale["orderSource"]
        }
      end)

    {:ok, %{sales: transformed_sales}}
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
