defmodule Lux.Lenses.PancakeSwap.YieldFarm do
  @moduledoc """
  Lens for fetching PancakeSwap yield farming position and reward data.

  Provides yield farming automation data including APY, reward tokens,
  and position tracking across multiple chains.

  ## Examples

      # Fetch yield farm info for a specific address
      iex> Lux.Lenses.PancakeSwap.YieldFarm.focus(%{"address" => "0x..."})
      {:ok, %{"farms" => [...]}}
  """

  use Lux.Lens,
    name: "PancakeSwap Yield Farm",
    description: "Fetches PancakeSwap yield farming positions and reward data",
    url: "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-bsc",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Wallet address to fetch farming positions for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        first: %{
          type: :integer,
          description: "Number of positions to return",
          default: 10
        },
        skip: %{
          type: :integer,
          description: "Number of positions to skip",
          default: 0
        }
      },
      required: []
    }

  @doc """
  Builds the GraphQL query for yield farming positions.
  """
  def before_focus(params \\ %{}) do
    params = params || %{}
    address = Map.get(params, :address, Map.get(params, "address", nil))
    first = Map.get(params, :first, Map.get(params, "first", 10))
    skip = Map.get(params, :skip, Map.get(params, "skip", 0))

    query =
      if address do
        """
        {
          positions(
            first: #{first},
            skip: #{skip},
            where: {owner: "#{address}"}
          ) {
            id
            pool { id token0 { symbol } token1 { symbol } feeTier totalValueLockedUSD }
            liquidity
            depositedToken0
            depositedToken1
            withdrawnToken0
            withdrawnToken1
            collectedFeesToken0
            collectedFeesToken1
          }
        }
        """
      else
        """
        {
          pools(first: #{first}, skip: #{skip}, orderBy: totalValueLockedUSD, orderDirection: desc) {
            id
            token0 { symbol address decimals }
            token1 { symbol address decimals }
            feeTier
            totalValueLockedUSD
            volumeUSD
          }
        }
        """
      end

    Map.put(Map.put(params, :query, query), :address, address)
  end

  @doc """
  Processes the GraphQL response for yield farming data.
  """
  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, "GraphQL errors: #{inspect(errors)}"}
  end

  def after_focus(_other) do
    {:error, "Unexpected response format from PancakeSwap subgraph"}
  end
end