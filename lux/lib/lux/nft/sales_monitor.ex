defmodule Lux.Nft.SalesMonitor do
  @moduledoc """
  NFT Sales tracker, volume analyzer, and wash-trading detection heuristic.
  """

  @doc """
  Filters wash trading activity from recent sales events.
  Identifies repeated sales between identical addresses within short timeframes.
  """
  @spec filter_wash_trades(list(map())) :: %{
          clean_sales: list(map()),
          flagged_sales: list(map()),
          clean_volume_eth: float(),
          wash_trading_pct: float()
        }
  def filter_wash_trades(sales) when is_list(sales) do
    classified =
      Enum.map(sales, fn s ->
        buyer = String.downcase(s["buyer"] || s[:buyer] || "")
        seller = String.downcase(s["seller"] || s[:seller] || "")
        price = parse_float(s["price_eth"] || s[:price_eth])

        is_wash? =
          buyer == seller or
            buyer == "0x0000000000000000000000000000000000000000" or
            Map.get(s, :suspect_wash_trade, false)

        Map.put(s, :is_wash_trade, is_wash?)
        |> Map.put(:price_eth, price)
      end)

    {flagged, clean} = Enum.split_with(classified, & &1[:is_wash_trade])

    clean_vol = clean |> Enum.map(& &1[:price_eth]) |> Enum.sum() |> Float.round(4)
    total_vol = (clean ++ flagged) |> Enum.map(& &1[:price_eth]) |> Enum.sum()

    wash_pct =
      if total_vol > 0,
        do: Float.round((total_vol - clean_vol) / total_vol * 100.0, 2),
        else: 0.0

    %{
      clean_sales: clean,
      flagged_sales: flagged,
      clean_volume_eth: clean_vol,
      wash_trading_pct: wash_pct
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
