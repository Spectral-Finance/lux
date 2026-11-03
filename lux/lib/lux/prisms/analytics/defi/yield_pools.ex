defmodule Lux.Prisms.Analytics.Defi.YieldPoolsPrism do
  @moduledoc """
  Filters and ranks yield opportunities across DeFi protocols.
  """

  use Lux.Prism,
    name: "DeFi Yield Pools",
    description: "Filters yield pools by minimum TVL, APY bounds, and target blockchain",
    input_schema: %{
      type: :object,
      properties: %{
        pools: %{type: :array, description: "List of yield pools from DeFiLlama"},
        min_tvl_usd: %{type: :number, default: 1_000_000.0},
        min_apy_pct: %{type: :number, default: 5.0},
        max_apy_pct: %{type: :number, default: 200.0},
        chain: %{type: :string}
      },
      required: ["pools"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        matching_pools: %{type: :array},
        pool_count: %{type: :integer}
      },
      required: ["matching_pools", "pool_count"]
    }

  alias Lux.Analytics.Defi.DefiLlama

  def handler(input, _ctx) do
    pools = Map.get(input, :pools) || Map.get(input, "pools", [])
    filtered = DefiLlama.filter_yield_pools(pools, input)

    {:ok,
     %{
       matching_pools: filtered,
       pool_count: length(filtered)
     }}
  end
end
