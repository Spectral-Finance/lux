defmodule Lux.Integrations.Binance.Portfolio do
  @moduledoc """
  Portfolio tracking, equity aggregation, and margin risk assessment across Binance Spot and Futures accounts.
  """

  @doc """
  Aggregates spot wallet balances and computes total estimated value in USDT.
  """
  @spec aggregate_spot_balances(list(map()), map()) :: %{
          balances: list(map()),
          total_spot_usdt: float()
        }
  def aggregate_spot_balances(raw_balances, prices \\ %{}) do
    non_zero =
      raw_balances
      |> Enum.map(fn b ->
        free = parse_float(b["free"] || b[:free])
        locked = parse_float(b["locked"] || b[:locked])
        total = free + locked
        asset = (b["asset"] || b[:asset] || "") |> String.upcase()

        price_usdt =
          cond do
            asset in ["USDT", "BUSD", "FDUSD", "USDC"] -> 1.0
            Map.has_key?(prices, asset <> "USDT") -> prices[asset <> "USDT"]
            true -> 0.0
          end

        value_usdt = total * price_usdt

        %{
          asset: asset,
          free: free,
          locked: locked,
          total: total,
          value_usdt: Float.round(value_usdt, 2)
        }
      end)
      |> Enum.filter(fn b -> b.total > 0.0 end)

    total_usdt =
      non_zero
      |> Enum.map(& &1.value_usdt)
      |> Enum.sum()
      |> Float.round(2)

    %{balances: non_zero, total_spot_usdt: total_usdt}
  end

  @doc """
  Assesses futures account margin risk.
  """
  @spec evaluate_futures_risk(float(), float(), float()) :: %{
          margin_ratio_pct: float(),
          health_status: :safe | :warning | :critical,
          liquidation_risk: float()
        }
  def evaluate_futures_risk(total_maintenance_margin, total_margin_balance, total_wallet_balance)
      when total_margin_balance > 0 do
    margin_ratio = total_maintenance_margin / total_margin_balance * 100.0

    status =
      cond do
        margin_ratio >= 85.0 -> :critical
        margin_ratio >= 65.0 -> :warning
        true -> :safe
      end

    liq_risk = Float.round(min(margin_ratio / 100.0, 1.0), 4)

    %{
      margin_ratio_pct: Float.round(margin_ratio, 2),
      health_status: status,
      liquidation_risk: liq_risk
    }
  end

  def evaluate_futures_risk(_mm, _mb, _wb) do
    %{margin_ratio_pct: 0.0, health_status: :safe, liquidation_risk: 0.0}
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0
end
