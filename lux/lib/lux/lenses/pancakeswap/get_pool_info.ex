defmodule Lux.Lenses.PancakeSwap.GetPoolInfo do
  @moduledoc """
  A lens for getting detailed information about a specific PancakeSwap pool.
  """

  alias Lux.Integrations.PancakeSwap

  use Lux.Lens,
    name: "Get PancakeSwap Pool Info",
    description: "Fetches detailed info for a specific pool by its address",
    method: :post,
    headers: PancakeSwap.headers(),
    schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, enum: ["bsc", "ethereum", "arbitrum", "base"], default: "bsc"},
        pool_address: %{type: :string, description: "The contract address of the pool"}
      },
      required: ["pool_address"]
    }

  @impl true
  def focus(input \\ %{}, opts \\ []) do
    chain = Map.get(input, :chain, Map.get(input, "chain", "bsc"))
    url = PancakeSwap.subgraph_url(chain)
    
    pool_address = Map.get(input, :pool_address, Map.get(input, "pool_address"))
    
    query = """
    {
      pool(id: "#{String.downcase(pool_address)}") {
        id
        token0 { id, symbol, name, decimals }
        token1 { id, symbol, name, decimals }
        feeTier
        liquidity
        sqrtPrice
        tick
        totalValueLockedToken0
        totalValueLockedToken1
        totalValueLockedUSD
        volumeUSD
        txCount
      }
    }
    """
    
    view()
    |> Map.put(:url, url)
    |> Map.put(:params, %{query: query})
    |> Lux.Lens.focus(opts)
  end

  @impl true
  def after_focus(%{"data" => %{"pool" => pool}}) do
    {:ok, pool}
  end

  def after_focus(error) do
    {:error, error}
  end
end
