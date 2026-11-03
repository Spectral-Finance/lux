defmodule Lux.Prisms.Defi.PancakeSwap.AutoCompoundPrism do
  @moduledoc """
  Generates and assesses auto-compounding plans for PancakeSwap yield farms.
  """

  use Lux.Prism,
    name: "AutoCompound PancakeSwap Farm",
    description: "Evaluates pending CAKE yield and plans token swap, liquidity addition, and re-stake",
    input_schema: %{
      type: :object,
      properties: %{
        pending_cake: %{type: :number, description: "Accrued CAKE tokens available to harvest"},
        cake_price_usd: %{type: :number, description: "Current CAKE price in USD"},
        price0_usd: %{type: :number, description: "Price of pool token 0 in USD"},
        price1_usd: %{type: :number, description: "Price of pool token 1 in USD"},
        gas_cost_usd: %{type: :number, default: 0.50}
      },
      required: ["pending_cake", "cake_price_usd", "price0_usd", "price1_usd"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        cake_harvested: %{type: :number},
        harvest_value_usd: %{type: :number},
        token0_amount: %{type: :number},
        token1_amount: %{type: :number},
        estimated_new_lp_usd: %{type: :number},
        viable?: %{type: :boolean}
      },
      required: ["cake_harvested", "harvest_value_usd", "token0_amount", "token1_amount", "viable?"]
    }

  alias Lux.Defi.PancakeSwap.Autocompounder

  def handler(input, _ctx) do
    pending_cake = (Map.get(input, :pending_cake) || Map.get(input, "pending_cake", 0.0)) * 1.0
    cake_price = (Map.get(input, :cake_price_usd) || Map.get(input, "cake_price_usd", 2.50)) * 1.0
    price0 = (Map.get(input, :price0_usd) || Map.get(input, "price0_usd", 1.0)) * 1.0
    price1 = (Map.get(input, :price1_usd) || Map.get(input, "price1_usd", 1.0)) * 1.0
    gas_cost = (Map.get(input, :gas_cost_usd) || Map.get(input, "gas_cost_usd", 0.50)) * 1.0

    plan = Autocompounder.plan_autocompound(pending_cake, cake_price, price0, price1, gas_cost)
    {:ok, plan}
  end
end
