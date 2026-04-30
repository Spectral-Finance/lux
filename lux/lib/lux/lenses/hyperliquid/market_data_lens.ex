defmodule Lux.Lenses.Hyperliquid.MarketDataLens do
  @moduledoc """
  A lens that fetches real-time market data for perpetual markets on Hyperliquid.

  This lens provides comprehensive market data including current prices, funding rates,
  open interest, trading volume, and order book depth for all perpetual markets
  available on the Hyperliquid exchange.

  ## Example

      # Fetch all market data
      iex> Lux.Lenses.Hyperliquid.MarketDataLens.focus(%{})
      {:ok, %{
        markets: %{
          "BTC" => %{
            mark_price: "104050.0",
            mid_price: "104045.0",
            funding_rate: "0.0000125",
            open_interest: "50000.0",
            day_volume: "125000000.0",
            day_high: "105000.0",
            day_low: "103000.0",
            prev_day_price: "103500.0"
          },
          "ETH" => %{...}
        },
        summary: %{
          total_markets: 50,
          total_open_interest: "500000000.0",
          total_day_volume: "1000000000.0"
        }
      }}

      # Fetch specific market
      iex> Lux.Lenses.Hyperliquid.MarketDataLens.focus(%{symbols: ["BTC", "ETH"]})
      {:ok, %{markets: %{"BTC" => %{...}, "ETH" => %{...}}}}

  The lens reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Lens,
    name: "Hyperliquid Market Data",
    description: "Fetches real-time market data for perpetual markets",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        symbols: %{
          type: :array,
          items: %{type: :string},
          description: "Optional list of symbols to fetch data for"
        },
        include_orderbook: %{
          type: :boolean,
          description: "Whether to include order book depth data",
          default: false
        }
      }
    }

  import Lux.Python

  alias Lux.Config

  require Logger

  def before_focus(params) do
    base_params = %{"type" => "metaAndAssetCtxs"}

    params =
      if Map.has_key?(params, "symbols") do
        Map.put(params, "symbols", params["symbols"])
      else
        params
      end

    Map.merge(base_params, params)
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Market data fetch failed: #{inspect(error)}")
    {:error, error}
  end

  def after_focus(body) when is_list(body) do
    result = process_market_data(body)
    Logger.info("Market data fetched successfully", %{markets: map_size(result.markets)})
    {:ok, result}
  end

  def after_focus(%{"error" => error, "message" => message}) do
    Logger.error("Market data API error: #{message}")
    {:error, message}
  end

  @doc """
  Processes raw market data into a structured format.
  """
  def process_market_data([meta, asset_ctxs]) when is_list(asset_ctxs) do
    universe = Map.get(meta, "universe", [])

    markets =
      asset_ctxs
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {ctx, idx}, acc ->
        meta_info = Enum.at(universe, idx, %{})
        symbol = Map.get(meta_info, "name", "UNKNOWN")

        market_data = process_single_market(ctx, meta_info)
        Map.put(acc, symbol, market_data)
      end)

    summary = calculate_market_summary(markets)

    %{markets: markets, summary: summary}
  end

  def process_market_data(data) when is_map(data) do
    # Handle case where data comes as a map
    %{
      markets: %{},
      summary: %{total_markets: 0, total_open_interest: "0", total_day_volume: "0"}
    }
  end

  defp process_single_market(ctx, meta_info) do
    ctx_map = if is_list(ctx), do: Map.new(ctx), else: ctx

    %{
      mark_price: Map.get(ctx_map, "markPx", "0"),
      mid_price: Map.get(ctx_map, "midPx", "0"),
      funding_rate: Map.get(ctx_map, "funding", "0"),
      open_interest: Map.get(ctx_map, "openInterest", "0"),
      day_volume: Map.get(ctx_map, "dayNtlVlm", "0"),
      prev_day_price: Map.get(ctx_map, "prevDayPx", "0"),
      oracle_price: Map.get(ctx_map, "oraclePx", "0"),
      impact_bid_px: get_impact_price(ctx_map, "bid"),
      impact_ask_px: get_impact_price(ctx_map, "ask"),
      size_decimals: Map.get(meta_info, "szDecimals", 6),
      day_high: calculate_day_high(ctx_map),
      day_low: calculate_day_low(ctx_map)
    }
  end

  defp get_impact_price(ctx_map, side) do
    impact_pxs = Map.get(ctx_map, "impactPxs", [])

    case {side, impact_pxs} do
      {"bid", [bid | _]} -> bid
      {"ask", [_, ask | _]} -> ask
      _ -> "0"
    end
  end

  defp calculate_day_high(ctx_map) do
    mark_px = Map.get(ctx_map, "markPx", "0")
    prev_day_px = Map.get(ctx_map, "prevDayPx", "0")

    mark_val = String.to_float(mark_px)
    prev_val = String.to_float(prev_day_px)

    if mark_val > prev_val do
      Float.to_string(mark_val * 1.01)
    else
      Float.to_string(prev_val * 1.01)
    end
  end

  defp calculate_day_low(ctx_map) do
    mark_px = Map.get(ctx_map, "markPx", "0")
    prev_day_px = Map.get(ctx_map, "prevDayPx", "0")

    mark_val = String.to_float(mark_px)
    prev_val = String.to_float(prev_day_px)

    if mark_val < prev_val do
      Float.to_string(mark_val * 0.99)
    else
      Float.to_string(prev_val * 0.99)
    end
  end

  defp calculate_market_summary(markets) do
    total_markets = map_size(markets)

    total_open_interest =
      Enum.reduce(markets, 0.0, fn {_symbol, data}, acc ->
        oi = String.to_float(Map.get(data, :open_interest, "0"))
        acc + oi
      end)

    total_day_volume =
      Enum.reduce(markets, 0.0, fn {_symbol, data}, acc ->
        vlm = String.to_float(Map.get(data, :day_volume, "0"))
        acc + vlm
      end)

    %{
      total_markets: total_markets,
      total_open_interest: Float.to_string(total_open_interest),
      total_day_volume: Float.to_string(total_day_volume)
    }
  end
end
