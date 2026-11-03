defmodule Lux.Defi.SushiSwap.BridgeMonitor do
  @moduledoc """
  Cross-chain bridge safety monitor, slippage enforcement, and ASCII status dashboard.
  """

  @doc """
  Verifies whether a cross-chain quote complies with safety thresholds.
  """
  @spec verify_bridge_safety(float(), float(), float(), float()) :: %{
          safe?: boolean(),
          slippage_pct: float(),
          fee_ratio_pct: float(),
          warning: String.t() | nil
        }
  def verify_bridge_safety(amount_in_usd, fee_usd, est_out_usd, max_slippage_pct \\ 1.0)
      when amount_in_usd > 0 do
    fee_ratio = Float.round(fee_usd / amount_in_usd * 100.0, 2)
    loss = max(amount_in_usd - est_out_usd, 0.0)
    slippage = Float.round(loss / amount_in_usd * 100.0, 2)

    warning =
      cond do
        fee_ratio > 5.0 -> "Bridge fee exceeds 5% of transfer notional value"
        slippage > max_slippage_pct -> "Slippage #{slippage}% exceeds maximum allowance #{max_slippage_pct}%"
        true -> nil
      end

    %{
      safe?: is_nil(warning),
      slippage_pct: slippage,
      fee_ratio_pct: fee_ratio,
      warning: warning
    }
  end

  def verify_bridge_safety(_, _, _, _), do: %{safe?: false, slippage_pct: 0.0, fee_ratio_pct: 0.0, warning: "Invalid input"}

  @doc """
  Renders an ASCII dashboard for cross-chain bridge transfer status.
  """
  @spec render_dashboard(list(map())) :: String.t()
  def render_dashboard(transfers) when is_list(transfers) do
    header = """
+------------------------------------------------------------------------------------+
|                         SUSHIXSWAP CROSS-CHAIN BRIDGE DASHBOARD                    |
+------------------------------------------------------------------------------------+
| Route                  | Token    | Amount In    | Min Out      | Est. Time | Status
+------------------------+----------+--------------+--------------+-----------+------
"""

    rows =
      Enum.map_join(transfers, "\n", fn t ->
        route = "#{t[:src_chain]} -> #{t[:dst_chain]}" |> String.slice(0, 22) |> String.pad_trailing(22)
        token = (t[:token] || "USDC") |> String.slice(0, 8) |> String.pad_trailing(8)
        in_amt = "#{t[:amount_in] || 0.0}" |> String.slice(0, 12) |> String.pad_trailing(12)
        out_amt = "#{t[:min_amount_out] || 0.0}" |> String.slice(0, 12) |> String.pad_trailing(12)
        time = "#{t[:estimated_minutes] || 5}m" |> String.pad_trailing(9)
        status = to_string(t[:status] || "CONFIRMED") |> String.pad_trailing(10)

        "| #{route} | #{token} | #{in_amt} | #{out_amt} | #{time} | #{status} |"
      end)

    footer = "\n+------------------------------------------------------------------------------------+\n"
    header <> rows <> footer
  end
end
