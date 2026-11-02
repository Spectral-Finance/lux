defmodule Lux.Prisms.Defi.UniswapV3.RebalancePositionPrism do
  @moduledoc """
  Generates automated rebalance plans for out-of-range or boundary-approaching positions.
  """

  use Lux.Prism,
    name: "Rebalance Uniswap V3 Position",
    description: "Evaluates rebalance necessity and generates new centered position boundaries",
    input_schema: %{
      type: :object,
      properties: %{
        position: %{type: :object, description: "Position map with ticks, fee, and token_id"},
        current_tick: %{type: :integer, description: "Current pool tick"},
        strategy: %{type: :string, enum: ["narrow", "moderate", "wide", "bullish", "bearish"], default: "moderate"},
        buffer_ratio: %{type: :number, default: 0.85},
        gas_cost_usd: %{type: :number, default: 15.0},
        position_capital_usd: %{type: :number, default: 5000.0}
      },
      required: ["position", "current_tick"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        reason: %{type: :string},
        old_position_id: %{type: :string},
        new_tick_lower: %{type: :integer},
        new_tick_upper: %{type: :integer},
        viable: %{type: :boolean},
        estimated_gas_cost_usd: %{type: :number}
      },
      required: ["action", "reason", "old_position_id", "viable"]
    }

  alias Lux.Defi.UniswapV3.RebalanceEngine

  def handler(input, _ctx) do
    raw_pos = Map.get(input, :position) || Map.get(input, "position")
    current_tick = Map.get(input, :current_tick) || Map.get(input, "current_tick")
    raw_strategy = Map.get(input, :strategy) || Map.get(input, "strategy", "moderate")
    buffer_ratio = Map.get(input, :buffer_ratio) || Map.get(input, "buffer_ratio", 0.85)
    gas_cost = Map.get(input, :gas_cost_usd) || Map.get(input, "gas_cost_usd", 15.0)
    capital = Map.get(input, :position_capital_usd) || Map.get(input, "position_capital_usd", 5000.0)

    strategy = if is_binary(raw_strategy), do: String.to_atom(raw_strategy), else: raw_strategy

    position = %{
      token_id: Map.get(raw_pos, :token_id) || Map.get(raw_pos, "token_id", "pos_default"),
      tick_lower: Map.get(raw_pos, :tick_lower) || Map.get(raw_pos, "tick_lower", 0),
      tick_upper: Map.get(raw_pos, :tick_upper) || Map.get(raw_pos, "tick_upper", 1000),
      fee: Map.get(raw_pos, :fee) || Map.get(raw_pos, "fee", 3000)
    }

    opts = [
      buffer_ratio: buffer_ratio,
      gas_cost_usd: gas_cost,
      position_capital_usd: capital
    ]

    case RebalanceEngine.plan_rebalance(position, current_tick, strategy, opts) do
      {:ok, plan} ->
        {:ok,
         %{
           action: to_string(plan.action),
           reason: plan.reason,
           old_position_id: to_string(plan.old_position_id),
           new_tick_lower: plan.new_tick_lower,
           new_tick_upper: plan.new_tick_upper,
           viable: plan.viable?,
           estimated_gas_cost_usd: plan.estimated_gas_cost_usd
         }}

      {:error, reason} ->
        {:error, "Rebalance planning failed: #{inspect(reason)}"}
    end
  end
end
