defmodule Lux.Prisms.Curve.ClaimRewards do
  @moduledoc """
  A prism for claiming accumulated CRV rewards and secondary incentive tokens from Curve gauges,
  with automated gas profitability threshold checks.
  """

  use Lux.Prism,
    name: "Curve Claim Rewards",
    description: "Harvests CRV and external incentive tokens from Curve gauges when gas profitable",
    input_schema: %{
      type: :object,
      properties: %{
        gauge_address: %{
          type: :string,
          pattern: "^0x[a-fA-F0-9]{40}$",
          description: "Target gauge address"
        },
        min_reward_usd_value: %{
          type: :number,
          description: "Minimum accrued reward in USD to justify transaction gas",
          default: 15.0
        },
        crv_price_usd: %{
          type: :number,
          description: "Current oracle price of CRV in USD",
          default: 0.50
        },
        gas_cost_usd: %{
          type: :number,
          description: "Estimated Ethereum transaction fee in USD",
          default: 3.50
        }
      },
      required: ["gauge_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        claimed: %{type: :boolean},
        gauge_address: %{type: :string},
        crv_harvested: %{type: :string},
        net_profit_usd: %{type: :number},
        skip_reason: %{type: :string}
      },
      required: ["claimed", "gauge_address"]
    }

  require Logger

  def handler(params, agent) do
    gauge_address = Map.get(params, :gauge_address)
    min_val = Map.get(params, :min_reward_usd_value, 15.0)
    crv_price = Map.get(params, :crv_price_usd, 0.50)
    gas_cost = Map.get(params, :gas_cost_usd, 3.50)
    agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"

    Logger.info("Agent #{agent_name} checking Curve rewards harvest on #{gauge_address}")

    # Simulated pending CRV accumulation (e.g. 50 CRV = $25 USD)
    pending_crv = 50.0
    gross_reward_usd = pending_crv * crv_price

    if gross_reward_usd >= min_val and gross_reward_usd > gas_cost do
      net_profit = Float.round(gross_reward_usd - gas_cost, 2)

      {:ok, %{
        claimed: true,
        gauge_address: gauge_address,
        crv_harvested: "#{pending_crv} CRV",
        net_profit_usd: net_profit,
        skip_reason: nil
      }}
    else
      {:ok, %{
        claimed: false,
        gauge_address: gauge_address,
        crv_harvested: "0 CRV",
        net_profit_usd: 0.0,
        skip_reason: "Gross reward ($#{gross_reward_usd}) below minimum profitability threshold ($#{min_val})"
      }}
    end
  end
end
