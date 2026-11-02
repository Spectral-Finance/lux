defmodule Lux.Prisms.Defi.Curve.CheckGaugeBoostPrism do
  @moduledoc """
  Calculates veCRV gauge boost factor and working balance for a Curve staker.
  """

  use Lux.Prism,
    name: "Check Curve Gauge Boost",
    description: "Calculates veCRV boost multiplier (1.0x to 2.5x) and effective working balance",
    input_schema: %{
      type: :object,
      properties: %{
        user_lp: %{type: :number, description: "User staked LP balance"},
        total_gauge_lp: %{type: :number, description: "Total LP staked in gauge"},
        user_vecrv: %{type: :number, description: "User veCRV balance", default: 0.0},
        total_vecrv: %{type: :number, description: "Total veCRV supply", default: 500000000.0}
      },
      required: ["user_lp", "total_gauge_lp"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        boost: %{type: :number},
        working_balance: %{type: :number},
        max_boosted: %{type: :boolean}
      },
      required: ["boost", "working_balance", "max_boosted"]
    }

  alias Lux.Defi.Curve.GaugeManager

  def handler(input, _ctx) do
    user_lp = Map.get(input, :user_lp) || Map.get(input, "user_lp", 0.0)
    total_lp = Map.get(input, :total_gauge_lp) || Map.get(input, "total_gauge_lp", 1.0)
    user_vecrv = Map.get(input, :user_vecrv) || Map.get(input, "user_vecrv", 0.0)
    total_vecrv = Map.get(input, :total_vecrv) || Map.get(input, "total_vecrv", 500_000_000.0)

    result = GaugeManager.calculate_boost(user_lp, total_lp, user_vecrv, total_vecrv)

    {:ok,
     %{
       boost: result.boost,
       working_balance: result.working_balance,
       max_boosted: result.max_boosted?
     }}
  end
end
