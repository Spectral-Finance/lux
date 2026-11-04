defmodule Lux.Lenses.PancakeSwap.Pools do
  @moduledoc """
  Lens for fetching PancakeSwap V3 pool data from the BSC subgraph.

  Provides multi-chain pool management with liquidity and TVL metrics.

  ## Examples

      # Fetch top pools by TVL
      iex> Lux.Lenses.PancakeSwap.Pools.focus(%{})
      {:ok, %{"data" => %{"pools" => [...]}}}

      # Fetch pools with custom limit
      iex> Lux.Lenses.PancakeSwap.Pools.focus(%{"first" => 10})
  """

  use Lux.Lens,
    name: "PancakeSwap Pools",
    description: "Fetches PancakeSwap V3 pool data from the BSC subgraph for yield farming and liquidity provision",
    url: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-bsc",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        first: %{
          type: :integer,
          description: "Number of pools to return",
          default: 5
        },
        skip: %{
          type: :integer,
          description: "Number of pools to skip for pagination",
          default: 0
        },
        orderBy: %{
          type: :string,
          description: "Field to order pools by",
          enum: ["totalValueLockedUSD", "volumeUSD", "feesUSD"],
          default: "totalValueLockedUSD"
        },
        orderDirection: %{
          type: :string,
          description: "Ordering direction",
          enum: ["asc", "desc"],
          default: "desc"
        }
      },
      required: []
    }

  @doc """
  Builds the GraphQL query string from input parameters.
  """
  def before_focus(params \\ %{}) do
    params = params || %{}
    first = Map.get(params, :first, Map.get(params, "first", 5))
    skip = Map.get(params, :skip, Map.get(params, "skip", 0))
    order_by = Map.get(params, :orderBy, Map.get(params, "orderBy", "totalValueLockedUSD"))
    order_dir = Map.get(params, :orderDirection, Map.get(params, "orderDirection", "desc"))

    query = """
    {
      pools(first: #{first}, skip: #{skip}, orderBy: #{order_by}, orderDirection: #{order_dir}) {
        id
        token0 { symbol address decimals }
        token1 { symbol address decimals }
        feeTier
        totalValueLockedUSD
        volumeUSD
        feesUSD
        liquidity
      }
    }
    """

    Map.put(params, :query, query)
  end

  @doc """
  Processes the GraphQL response into a usable format.
  """
  def after_focus(%{"data" => %{"pools" => pools}}) do
    {:ok, %{"pools" => pools, "count" => length(pools)}}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, "GraphQL errors: #{inspect(errors)}"}
  end

  def after_focus(_other) do
    {:error, "Unexpected response format from PancakeSwap subgraph"}
  end
end