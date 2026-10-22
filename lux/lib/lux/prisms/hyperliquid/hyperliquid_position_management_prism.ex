defmodule Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrism do
  @moduledoc """
  A prism that evaluates perpetual positions, margin health ratios, and calculates liquidation safety margins.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrism.run(%{
      ...>   positions: [%{coin: "ETH", size: 1.0, entry_price: 2500.0, liquidation_price: 2200.0}],
      ...>   account_value: 10000.0,
      ...>   total_ntl_pos: 2500.0,
      ...>   margin_threshold: 0.1
      ...> })
      {:ok, %{
        status: "success",
        margin_ratio: 4.0,
        risk_level: "low",
        liquidation_distance: 0.12,
        recommended_actions: []
      }}
  """

  use Lux.Prism,
    name: "Hyperliquid Position Management",
    description: "Evaluates position health, liquidation distance, and margin risk ratios",
    input_schema: %{
      type: :object,
      properties: %{
        positions: %{
          type: :array,
          description: "List of active positions from clearinghouse state"
        },
        account_value: %{
          type: :number,
          description: "Total account value in USD"
        },
        total_ntl_pos: %{
          type: :number,
          description: "Total notional position value"
        },
        margin_threshold: %{
          type: :number,
          description: "Critical margin threshold (default: 0.1)",
          default: 0.1
        }
      },
      required: ["positions", "account_value"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        margin_ratio: %{type: :number},
        risk_level: %{type: :string, enum: ["low", "moderate", "high", "critical"]},
        liquidation_distance: %{type: :number},
        recommended_actions: %{type: :array, items: %{type: :string}},
        position_count: %{type: :integer}
      },
      required: ["status", "margin_ratio", "risk_level"]
    }

  require Logger

  def handler(%{positions: positions, account_value: account_value} = input, _ctx) do
    total_ntl_pos = Map.get(input, :total_ntl_pos, 0.0)
    margin_threshold = Map.get(input, :margin_threshold, 0.1)

    account_val = to_f(account_value)
    total_ntl = to_f(total_ntl_pos)

    margin_ratio =
      if total_ntl > 0.0 do
        account_val / total_ntl
      else
        1.0
      end

    min_liq_dist =
      positions
      |> Enum.map(fn pos ->
        entry = to_f(pos[:entry_price] || pos["entry_price"] || pos["entryPx"])
        liq = to_f(pos[:liquidation_price] || pos["liquidation_price"] || pos["liquidationPx"])

        if entry > 0.0 and liq > 0.0 do
          abs(entry - liq) / entry
        else
          1.0
        end
      end)
      |> case do
        [] -> 1.0
        dists -> Enum.min(dists)
      end

    {risk_level, actions} =
      cond do
        margin_ratio < margin_threshold or min_liq_dist < 0.03 ->
          {"critical", ["reduce_position", "add_margin", "activate_stop_loss"]}

        margin_ratio < margin_threshold * 2.0 or min_liq_dist < 0.06 ->
          {"high", ["tighten_stop_loss", "monitor_margin"]}

        margin_ratio < margin_threshold * 4.0 or min_liq_dist < 0.10 ->
          {"moderate", ["monitor_leverage"]}

        true ->
          {"low", []}
      end

    Logger.info(
      "Position management assessment: risk_level=#{risk_level}, margin_ratio=#{margin_ratio}"
    )

    {:ok,
     %{
       status: "success",
       margin_ratio: Float.round(margin_ratio, 4),
       risk_level: risk_level,
       liquidation_distance: Float.round(min_liq_dist, 4),
       recommended_actions: actions,
       position_count: length(positions)
     }}
  end

  defp to_f(nil), do: 0.0
  defp to_f(val) when is_float(val), do: val
  defp to_f(val) when is_integer(val), do: val * 1.0

  defp to_f(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp to_f(_), do: 0.0
end
