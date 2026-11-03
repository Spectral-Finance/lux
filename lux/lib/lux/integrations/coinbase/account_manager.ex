defmodule Lux.Integrations.Coinbase.AccountManager do
  @moduledoc """
  Coinbase Account and Portfolio Management:
  - Account balance aggregation across fiat and crypto assets
  - Portfolio valuation in USD
  - Fee tier calculation (maker and taker fee rates)
  """

  @doc """
  Aggregates non-zero balances from Coinbase accounts list.
  """
  @spec aggregate_accounts(list(map()), map()) :: %{
          accounts: list(map()),
          total_portfolio_usd: float()
        }
  def aggregate_accounts(accounts, prices \\ %{}) when is_list(accounts) do
    parsed_accounts =
      accounts
      |> Enum.map(fn acc ->
        currency = acc["currency"] || acc[:currency] || ""
        available = parse_float(get_in(acc, ["available_balance", "value"]) || acc["available"] || 0.0)
        hold = parse_float(get_in(acc, ["hold", "value"]) || acc["hold"] || 0.0)
        total = available + hold

        price_usd =
          cond do
            currency in ["USD", "USDC", "USDT"] -> 1.0
            Map.has_key?(prices, currency <> "-USD") -> prices[currency <> "-USD"]
            true -> 0.0
          end

        value_usd = total * price_usd

        %{
          uuid: acc["uuid"] || acc[:uuid],
          name: acc["name"] || currency,
          currency: currency,
          available: available,
          hold: hold,
          total: total,
          value_usd: Float.round(value_usd, 2)
        }
      end)
      |> Enum.filter(fn a -> a.total > 0.0 end)

    total_usd =
      parsed_accounts
      |> Enum.map(& &1.value_usd)
      |> Enum.sum()
      |> Float.round(2)

    %{accounts: parsed_accounts, total_portfolio_usd: total_usd}
  end

  @doc """
  Estimates fee costs for a trade based on volume tier.
  """
  @spec estimate_trade_fee(float(), float(), :maker | :taker, float(), float()) :: %{
          notional_usd: float(),
          fee_rate_bps: float(),
          estimated_fee_usd: float(),
          net_notional_usd: float()
        }
  def estimate_trade_fee(quantity, price, fee_type \\ :taker, maker_fee_bps \\ 40.0, taker_fee_bps \\ 60.0)
      when quantity > 0 and price > 0 do
    notional = quantity * price
    bps = if fee_type == :maker, do: maker_fee_bps, else: taker_fee_bps
    fee_rate = bps / 10000.0
    fee_usd = Float.round(notional * fee_rate, 4)
    net_notional = Float.round(notional - fee_usd, 2)

    %{
      notional_usd: Float.round(notional, 2),
      fee_rate_bps: bps,
      estimated_fee_usd: fee_usd,
      net_notional_usd: net_notional
    }
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
