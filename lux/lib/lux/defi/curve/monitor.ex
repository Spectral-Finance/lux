defmodule Lux.Defi.Curve.Monitor do
  @moduledoc """
  Health monitoring, depeg risk assessment, and ASCII dashboard generator
  for Curve Finance stablecoin positions.
  """

  @doc """
  Evaluates pool health and stability score (0-100).
  """
  @spec evaluate_pool_health(list(number()), float()) :: %{
          score: integer(),
          status: :healthy | :skewed | :depeg_risk,
          max_deviation_pct: float(),
          alerts: list(String.t())
        }
  def evaluate_pool_health(balances, threshold_pct \\ 0.05) when is_list(balances) do
    total = max(Enum.sum(balances), 1.0)
    ideal_share = 1.0 / length(balances)

    shares = Enum.map(balances, &(&1 / total))
    max_dev = Enum.map(shares, &abs(&1 - ideal_share)) |> Enum.max()
    dev_pct = Float.round(max_dev * 100.0, 2)

    cond do
      dev_pct >= 20.0 ->
        %{
          score: 30,
          status: :depeg_risk,
          max_deviation_pct: dev_pct,
          alerts: ["Severe coin imbalance detected (> 20%)", "Possible depeg risk"]
        }

      dev_pct >= threshold_pct * 100.0 ->
        %{
          score: 75,
          status: :skewed,
          max_deviation_pct: dev_pct,
          alerts: ["Mild pool imbalance, bonus LP opportunity available"]
        }

      true ->
        %{
          score: 100,
          status: :healthy,
          max_deviation_pct: dev_pct,
          alerts: []
        }
    end
  end

  @doc """
  Generates an ASCII dashboard table of active Curve stablecoin positions.
  """
  @spec render_dashboard(list(map())) :: String.t()
  def render_dashboard(positions) when is_list(positions) do
    header = """
+---------------------------------------------------------------------------------------------------+
|                            CURVE STABLECOIN MANAGEMENT DASHBOARD                                  |
+---------------------------------------------------------------------------------------------------+
| Pool ID      | Pool Name         | Virt Price | Value ($)  | Boost | Total APY  | Status   | Health   |
+--------------+-------------------+------------+------------+-------+------------+----------+----------+
"""

    rows =
      Enum.map_join(positions, "\n", fn p ->
        id = (p[:pool_id] || "3pool") |> String.slice(0, 12) |> String.pad_trailing(12)
        name = (p[:name] || "Curve 3pool") |> String.slice(0, 17) |> String.pad_trailing(17)
        vp = "#{p[:virtual_price] || 1.0}" |> String.slice(0, 10) |> String.pad_trailing(10)
        val = "$#{p[:value_usd] || 0}" |> String.slice(0, 10) |> String.pad_trailing(10)
        boost = "#{p[:boost] || 1.0}x" |> String.slice(0, 5) |> String.pad_trailing(5)
        apy = "#{p[:total_apy] || 0.0}%" |> String.slice(0, 10) |> String.pad_trailing(10)
        status = to_string(p[:status] || "healthy") |> String.pad_trailing(8)
        health = "#{p[:health_score] || 100}%" |> String.pad_trailing(8)

        "| #{id} | #{name} | #{vp} | #{val} | #{boost} | #{apy} | #{status} | #{health} |"
      end)

    footer = "\n+---------------------------------------------------------------------------------------------------+\n"
    header <> rows <> footer
  end
end
