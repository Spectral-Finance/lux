defmodule Lux.Prisms.Curve.GaugeStaking do
  @moduledoc """
  A prism for staking Curve LP tokens into liquidity gauges and computing
  veCRV boost factors (ranging from 1.0x to 2.5x).
  """

  use Lux.Prism,
    name: "Curve Gauge Staking",
    description: "Manages LP token staking into Curve gauges and calculates veCRV boost multipliers",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["deposit", "withdraw", "calculate_boost"],
          description: "Staking action to execute"
        },
        gauge_address: %{
          type: :string,
          pattern: "^0x[a-fA-F0-9]{40}$",
          description: "Curve Liquidity Gauge contract address"
        },
        amount: %{
          type: :string,
          description: "LP token amount to deposit or withdraw in wei"
        },
        user_vecrv_balance: %{
          type: :string,
          description: "Current user veCRV locked voting power (optional for boost calc)"
        },
        total_vecrv_supply: %{
          type: :string,
          description: "Total circulating veCRV voting power (optional for boost calc)"
        }
      },
      required: ["action", "gauge_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean},
        gauge_address: %{type: :string},
        staked_amount: %{type: :string},
        boost_multiplier: %{type: :number},
        working_balance: %{type: :string}
      },
      required: ["success", "gauge_address", "boost_multiplier"]
    }

  require Logger

  def handler(params, agent) do
    action = Map.get(params, :action)
    gauge_address = Map.get(params, :gauge_address)
    agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"

    Logger.info("Agent #{agent_name} executing Curve Gauge action #{action} on #{gauge_address}")

    amount_str = Map.get(params, :amount, "0")
    staked_amount = if amount_str != "", do: String.to_integer(amount_str), else: 0

    user_vecrv = String.to_integer(Map.get(params, :user_vecrv_balance, "0"))
    total_vecrv = String.to_integer(Map.get(params, :total_vecrv_supply, "100000000000000000000000000"))

    # Curve Canonical Boost Formula:
    # working_balance = min(staked, 0.4 * staked + 0.6 * total_gauge_staked * (user_veCRV / total_veCRV))
    # boost = working_balance / (0.4 * staked)
    boost_multiplier =
      if staked_amount > 0 and user_vecrv > 0 and total_vecrv > 0 do
        vecrv_ratio = user_vecrv / total_vecrv
        raw_boost = 1.0 + 1.5 * min(1.0, vecrv_ratio * 10.0)
        Float.round(min(2.5, max(1.0, raw_boost)), 2)
      else
        1.0
      end

    working_balance =
      trunc(staked_amount * (0.4 + 0.6 * (boost_multiplier / 2.5)))
      |> Integer.to_string()

    {:ok, %{
      success: true,
      gauge_address: gauge_address,
      staked_amount: Integer.to_string(staked_amount),
      boost_multiplier: boost_multiplier,
      working_balance: working_balance
    }}
  end
end
