defmodule Lux.Prisms.Defi.SushiSwap.RouteProcessorPrism do
  @moduledoc """
  Calculates multi-hop swap route, final output amount, and price impact for SushiSwap.
  """

  use Lux.Prism,
    name: "SushiSwap RouteProcessor",
    description: "Calculates multi-hop swap execution, slippage, and price impact across pools",
    input_schema: %{
      type: :object,
      properties: %{
        amount_in: %{type: :number, description: "Input token amount"},
        pools: %{type: :array, description: "List of pool maps with reserve_in and reserve_out"}
      },
      required: ["amount_in", "pools"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        amount_in: %{type: :number},
        amount_out: %{type: :number},
        price_impact_pct: %{type: :number},
        hops: %{type: :integer}
      },
      required: ["amount_in", "amount_out", "price_impact_pct", "hops"]
    }

  alias Lux.Defi.SushiSwap.RouteProcessor

  def handler(input, _ctx) do
    amount_in = (Map.get(input, :amount_in) || Map.get(input, "amount_in", 0.0)) * 1.0
    pools = Map.get(input, :pools) || Map.get(input, "pools", [])

    parsed_pools =
      Enum.map(pools, fn p ->
        %{
          reserve_in: (p[:reserve_in] || p["reserve_in"] || 1000.0) * 1.0,
          reserve_out: (p[:reserve_out] || p["reserve_out"] || 1000.0) * 1.0
        }
      end)

    result = RouteProcessor.route_multihop(amount_in, parsed_pools)
    {:ok, result}
  end
end
