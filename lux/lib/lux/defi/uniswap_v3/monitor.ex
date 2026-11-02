defmodule Lux.Defi.UniswapV3.Monitor do
  @moduledoc """
  Health monitoring, performance tracking, and ASCII dashboard generator
  for Uniswap V3 concentrated liquidity positions.
  """

  alias Lux.Defi.UniswapV3.PositionManager
  alias Lux.Defi.UniswapV3.ImpermanentLoss

  @type health_report :: %{
          token_id: pos_integer() | String.t(),
          in_range?: boolean(),
          health_score: integer(),
          status: :healthy | :warning | :critical,
          il_pct: float(),
          alerts: list(String.t())
        }

  @doc """
  Evaluates the health score (0 to 100) and operational status of a position.
  """
  @spec check_health(PositionManager.position(), integer(), number(), number(), number(), number()) :: health_report()
  def check_health(position, current_tick, p_entry, p_current, p_lower, p_upper) do
    in_range = PositionManager.in_range?(position, current_tick)
    il_fraction = ImpermanentLoss.concentrated_il(p_entry, p_current, p_lower, p_upper)
    il_pct = Float.round(abs(il_fraction) * 100.0, 2)

    # Health score scoring:
    range_score = if in_range, do: 60, else: 10
    il_penalty = min(round(il_pct * 3.0), 40)
    score = max(range_score + (40 - il_penalty), 0)

    alerts =
      []
      |> append_if(not in_range, "Position is OUT OF RANGE, earning 0 fees")
      |> append_if(il_pct >= 10.0, "High impermanent loss (> 10%) detected")

    status =
      cond do
        score >= 70 -> :healthy
        score >= 40 -> :warning
        true -> :critical
      end

    %{
      token_id: position.token_id,
      in_range?: in_range,
      health_score: score,
      status: status,
      il_pct: il_pct,
      alerts: alerts
    }
  end

  @doc """
  Renders an ASCII performance dashboard table for a list of positions.
  """
  @spec render_dashboard(list(map())) :: String.t()
  def render_dashboard(positions_data) when is_list(positions_data) do
    header = """
+---------------------------------------------------------------------------------------------------+
|                            UNISWAP V3 LIQUIDITY MANAGEMENT DASHBOARD                              |
+---------------------------------------------------------------------------------------------------+
| ID       | Pair        | Fee   | Status       | Health | IL %   | Value ($)  | Est. APR % | Action  |
+----------+-------------+-------+--------------+--------+--------+------------+------------+---------+
"""

    rows =
      Enum.map_join(positions_data, "\n", fn p ->
        id = String.slice(to_string(p[:token_id] || "N/A"), 0, 8) |> String.pad_trailing(8)
        pair = (p[:pair] || "ETH/USDC") |> String.pad_trailing(11)
        fee = format_fee(p[:fee] || 3000) |> String.pad_trailing(5)
        status_str = if(p[:in_range?], do: "IN RANGE  ", else: "OUT OF RNG") |> String.pad_trailing(12)
        health = "#{p[:health_score] || 100}%" |> String.pad_trailing(6)
        il = "#{p[:il_pct] || 0.0}%" |> String.pad_trailing(6)
        val = "$#{p[:value_usd] || 0}" |> String.pad_trailing(10)
        apr = "#{p[:apr_pct] || 0.0}%" |> String.pad_trailing(10)
        act = (p[:action] || "HOLD") |> String.pad_trailing(7)

        "| #{id} | #{pair} | #{fee} | #{status_str} | #{health} | #{il} | #{val} | #{apr} | #{act} |"
      end)

    footer = "\n+---------------------------------------------------------------------------------------------------+\n"
    header <> rows <> footer
  end

  defp format_fee(100), do: "0.01%"
  defp format_fee(500), do: "0.05%"
  defp format_fee(3000), do: "0.30%"
  defp format_fee(10000), do: "1.00%"
  defp format_fee(f), do: "#{f}bp"

  defp append_if(list, condition, item) do
    if condition, do: [item | list], else: list
  end
end
