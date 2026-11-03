defmodule Lux.Analytics.Defi.Dashboard do
  @moduledoc """
  DeFi Analytics ASCII Dashboard generator for TVL, yields, and active protocol alerts.
  """

  @doc """
  Renders multi-chain and protocol TVL performance table.
  """
  @spec render_tvl_table(list(map())) :: String.t()
  def render_tvl_table(protocols) when is_list(protocols) do
    header = """
+------------------------------------------------------------------------------------+
|                           DEFI PROTOCOL TVL & METRICS OVERVIEW                     |
+------------------------------------------------------------------------------------+
| Protocol             | Category        | TVL ($M)      | 24h Change   | Chain Count|
+----------------------+-----------------+---------------+--------------+------------+
"""

    rows =
      Enum.map_join(protocols, "\n", fn p ->
        name = (p[:name] || p["name"] || "Unknown") |> String.slice(0, 20) |> String.pad_trailing(20)
        cat = (p[:category] || p["category"] || "DeFi") |> String.slice(0, 15) |> String.pad_trailing(15)
        tvl_m = Float.round((p[:total_tvl_usd] || p["total_tvl_usd"] || 0.0) / 1_000_000.0, 2)
        tvl_str = "$#{tvl_m}M" |> String.slice(0, 13) |> String.pad_trailing(13)
        chg = "#{p[:change_1d_pct] || p["change_1d_pct"] || 0.0}%" |> String.slice(0, 12) |> String.pad_trailing(12)
        chain_count = to_string(map_size(p[:chain_tvls] || p["chain_tvls"] || %{})) |> String.pad_trailing(10)

        "| #{name} | #{cat} | #{tvl_str} | #{chg} | #{chain_count} |"
      end)

    footer = "\n+------------------------------------------------------------------------------------+\n"
    header <> rows <> footer
  end

  @doc """
  Renders yield opportunities leaderboard table.
  """
  @spec render_yield_table(list(map())) :: String.t()
  def render_yield_table(pools) when is_list(pools) do
    header = """
+------------------------------------------------------------------------------------+
|                         DEFI YIELD OPPORTUNITIES LEADERBOARD                       |
+------------------------------------------------------------------------------------+
| Pool Symbol          | Project         | Chain         | TVL ($M)     | Total APY  |
+----------------------+-----------------+---------------+--------------+------------+
"""

    rows =
      Enum.map_join(pools, "\n", fn p ->
        symbol = (p[:symbol] || p["symbol"] || "") |> String.slice(0, 20) |> String.pad_trailing(20)
        proj = (p[:project] || p["project"] || "") |> String.slice(0, 15) |> String.pad_trailing(15)
        chain = (p[:chain] || p["chain"] || "") |> String.slice(0, 13) |> String.pad_trailing(13)
        tvl_m = Float.round((p[:tvl_usd] || p["tvl_usd"] || 0.0) / 1_000_000.0, 2)
        tvl_str = "$#{tvl_m}M" |> String.slice(0, 12) |> String.pad_trailing(12)
        apy = "#{p[:apy_pct] || p["apy_pct"] || 0.0}%" |> String.slice(0, 10) |> String.pad_trailing(10)

        "| #{symbol} | #{proj} | #{chain} | #{tvl_str} | #{apy} |"
      end)

    footer = "\n+------------------------------------------------------------------------------------+\n"
    header <> rows <> footer
  end
end
