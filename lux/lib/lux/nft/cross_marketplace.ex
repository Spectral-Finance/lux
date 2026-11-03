defmodule Lux.Nft.CrossMarketplace do
  @moduledoc """
  Cross-marketplace aggregation and comparison across OpenSea, Blur, and LooksRare:
  - Compares floor prices and active listings
  - Factors in marketplace protocol fees and creator royalties
  - Identifies lowest effective execution price
  """

  @marketplace_fees %{
    opensea: %{protocol_fee_pct: 2.5, royalty_enforced?: true},
    blur: %{protocol_fee_pct: 0.0, royalty_enforced?: false},
    looksrare: %{protocol_fee_pct: 2.0, royalty_enforced?: true}
  }

  @doc """
  Compares floor listings across marketplaces and calculates total buyer cost.
  """
  @spec compare_listings(list(map()), float()) :: %{
          best_marketplace: atom(),
          lowest_total_cost_eth: float(),
          listings: list(map())
        }
  def compare_listings(listings, creator_royalty_pct \\ 5.0) when is_list(listings) and length(listings) > 0 do
    evaluated =
      Enum.map(listings, fn l ->
        market = (l[:marketplace] || l["marketplace"] || "opensea") |> to_string() |> String.downcase() |> String.to_atom()
        price = parse_float(l[:price_eth] || l["price_eth"])

        fee_cfg = Map.get(@marketplace_fees, market, %{protocol_fee_pct: 2.5, royalty_enforced?: true})

        effective_royalty = if fee_cfg.royalty_enforced?, do: creator_royalty_pct, else: 0.5
        total_fee_pct = fee_cfg.protocol_fee_pct + effective_royalty
        total_cost = Float.round(price * (1.0 + total_fee_pct / 100.0), 4)

        %{
          marketplace: market,
          price_eth: price,
          protocol_fee_pct: fee_cfg.protocol_fee_pct,
          royalty_pct: effective_royalty,
          total_cost_eth: total_cost
        }
      end)
      |> Enum.sort_by(& &1.total_cost_eth, :asc)

    best = hd(evaluated)

    %{
      best_marketplace: best.marketplace,
      lowest_total_cost_eth: best.total_cost_eth,
      listings: evaluated
    }
  end

  def compare_listings(_, _) do
    %{best_marketplace: :opensea, lowest_total_cost_eth: 0.0, listings: []}
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
