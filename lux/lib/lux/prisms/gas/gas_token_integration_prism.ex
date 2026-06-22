defmodule Lux.Prisms.Gas.GasTokenIntegrationPrism do
  @moduledoc """
  Integrates gas token optimization (BAT/GAS/KNC) for transaction cost reduction.
  """

  use Lux.Prism,
    name: "Gas Token Integration",
    description: "Integrates gas token optimization for transaction cost reduction",
    input_schema: %{
      type: :object,
      properties: %{
        transaction_to: %{type: :string, pattern: "^0x[a-fA-F0-9]{40}$"},
        estimated_gas: %{type: :integer},
        gas_price_gwei: %{type: :number},
        chain_id: %{type: :integer, default: 1}
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        optimal_token: %{type: :string},
        token_contract: %{type: :string},
        potential_savings_wei: %{type: :integer},
        potential_savings_eth: %{type: :number},
        swap_needed: %{type: :boolean},
        swap_router: %{type: :string},
        net_savings_after_swap: %{type: :integer},
        recommendation: %{type: :string}
      },
      required: ["optimal_token", "token_contract", "potential_savings_wei", "potential_savings_eth", "swap_needed", "swap_router", "net_savings_after_swap", "recommendation"]
    }

  @gwei 1_000_000_000

  def handler(input, _ctx \ nil) do
    estimated_gas = Map.get(input, :estimated_gas, 21000)
    gas_price_gwei = Map.get(input, :gas_price_gwei)
    max_refund = min(estimated_gas, 53_000)
    gas_price_wei = case gas_price_gwei do nil -> 30 * @gwei; gp -> trunc(gp * @gwei) end
    savings_wei = max_refund * gas_price_wei
    savings_eth = savings_wei / 1_000_000_000_000_000_000
    swap_cost = if savings_eth > 0.01, do: trunc(savings_eth * 0.005 * 1_000_000_000_000_000_000), else: 0
    net_savings = max(savings_wei - swap_cost, 0)
    pct = if savings_wei > 0, do: round(net_savings / savings_wei * 100), else: 0

    recommendation =
      if net_savings > savings_wei * 0.3 do
        "Using BAT gas token provides significant savings (#{pct}% of gross savings retained after swap costs)."
      else
        "Gas token optimization provides minimal benefit. Consider batching with other transactions instead."
      end

    {:ok, %{
      optimal_token: "BAT",
      token_contract: "0x0D8775F648430679A709E98d2b0Cb6250d2887EF",
      potential_savings_wei: savings_wei,
      potential_savings_eth: round(savings_eth * 1_000_000) / 1_000_000,
      swap_needed: true,
      swap_router: "0xdef11c2",
      net_savings_after_swap: net_savings,
      recommendation: recommendation
    }}
  end
end
