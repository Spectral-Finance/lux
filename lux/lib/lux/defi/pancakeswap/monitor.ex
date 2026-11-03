defmodule Lux.Defi.PancakeSwap.Monitor do
  @moduledoc """
  Yield farming performance monitor, health assessment, and ASCII dashboard generator
  for multi-chain PancakeSwap positions.
  """

  @doc """
  Renders an ASCII performance dashboard table for PancakeSwap farms.
  """
  @spec render_dashboard(list(map())) :: String.t()
  def render_dashboard(farms) when is_list(farms) do
    header = """
+---------------------------------------------------------------------------------------------------+
|                            PANCAKESWAP MULTI-CHAIN YIELD FARMING DASHBOARD                        |
+---------------------------------------------------------------------------------------------------+
| PID  | Chain       | Pair        | Staked ($) | Pending CAKE | Daily ($)  | Total APY  | Status   |
+------+-------------+-------------+------------+--------------+------------+------------+----------+
"""

    rows =
      Enum.map_join(farms, "\n", fn f ->
        pid = to_string(f[:pid] || 0) |> String.pad_trailing(4)
        chain = (f[:chain_name] || "BSC") |> String.slice(0, 11) |> String.pad_trailing(11)
        pair = (f[:pair] || "CAKE/BNB") |> String.slice(0, 11) |> String.pad_trailing(11)
        staked = "$#{f[:staked_usd] || 0}" |> String.slice(0, 10) |> String.pad_trailing(10)
        pending = "#{f[:pending_cake] || 0.0}" |> String.slice(0, 12) |> String.pad_trailing(12)
        daily = "$#{f[:daily_yield_usd] || 0.0}" |> String.slice(0, 10) |> String.pad_trailing(10)
        apy = "#{f[:apy_pct] || 0.0}%" |> String.slice(0, 10) |> String.pad_trailing(10)
        status = to_string(f[:status] || "ACTIVE") |> String.pad_trailing(8)

        "| #{pid} | #{chain} | #{pair} | #{staked} | #{pending} | #{daily} | #{apy} | #{status} |"
      end)

    footer = "\n+---------------------------------------------------------------------------------------------------+\n"
    header <> rows <> footer
  end
end
