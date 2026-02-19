defmodule Lux.Lenses.Binance.MarketDataLens do
  @moduledoc """
  A lens that fetches market data from the Binance API.

  Supports fetching ticker prices, 24h statistics, order book depth,
  and recent trades for spot and futures markets.

  Unlike standard Lux lenses that use the `Lux.Lens` macro for simple HTTP GET
  requests, this lens uses the Binance Client for proper API integration
  including authentication support and endpoint routing.

  ## Examples

      # Get ticker price
      iex> Lux.Lenses.Binance.MarketDataLens.focus(%{
      ...>   type: "ticker_price",
      ...>   symbol: "BTCUSDT"
      ...> })
      {:ok, %{symbol: "BTCUSDT", price: "42000.00"}}

      # Get 24h ticker stats
      iex> Lux.Lenses.Binance.MarketDataLens.focus(%{
      ...>   type: "ticker_24h",
      ...>   symbol: "ETHUSDT"
      ...> })
      {:ok, %{symbol: "ETHUSDT", price_change: "-50.00", ...}}

      # Get order book depth
      iex> Lux.Lenses.Binance.MarketDataLens.focus(%{
      ...>   type: "depth",
      ...>   symbol: "BTCUSDT",
      ...>   limit: 10
      ...> })
      {:ok, %{bids: [...], asks: [...]}}
  """

  alias Lux.Integrations.Binance.Client

  require Logger

  @doc """
  Returns the lens metadata.
  """
  def view do
    %{
      name: "Binance Market Data",
      description: "Fetches market data from Binance (prices, depth, trades)",
      schema: %{
        type: :object,
        properties: %{
          type: %{
            type: :string,
            description: "Type of market data to fetch",
            enum: ["ticker_price", "ticker_24h", "depth", "recent_trades", "klines"]
          },
          symbol: %{
            type: :string,
            description: "Trading pair symbol (e.g., BTCUSDT)"
          },
          limit: %{
            type: :integer,
            description: "Number of results (for depth, trades, klines)"
          },
          interval: %{
            type: :string,
            description: "Kline interval (e.g., 1m, 5m, 1h, 1d)"
          },
          endpoint: %{
            type: :string,
            description: "API endpoint type: spot or futures",
            enum: ["spot", "futures"]
          }
        },
        required: ["type", "symbol"]
      }
    }
  end

  @doc """
  Focuses the lens to fetch the requested market data.

  ## Options

    * `:plug` - A Req.Test plug for testing
  """
  @spec focus(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def focus(params, opts \\ []) do
    plug = Keyword.get(opts, :plug, nil)
    endpoint = parse_endpoint(params)
    type = Map.fetch!(params, :type)

    fetch_data(type, params, endpoint, plug)
  end

  defp fetch_data("ticker_price", params, endpoint, plug) do
    Client.request(:get, api_path(endpoint, "/ticker/price"), %{symbol: params.symbol}, endpoint: endpoint, plug: plug)
    |> handle_result(fn data ->
      {:ok, %{symbol: data["symbol"], price: data["price"]}}
    end)
  end

  defp fetch_data("ticker_24h", params, endpoint, plug) do
    Client.request(:get, api_path(endpoint, "/ticker/24hr"), %{symbol: params.symbol}, endpoint: endpoint, plug: plug)
    |> handle_result(fn data ->
      {:ok, %{
        symbol: data["symbol"],
        price_change: data["priceChange"],
        price_change_percent: data["priceChangePercent"],
        weighted_avg_price: data["weightedAvgPrice"],
        last_price: data["lastPrice"],
        volume: data["volume"],
        quote_volume: data["quoteVolume"],
        open_price: data["openPrice"],
        high_price: data["highPrice"],
        low_price: data["lowPrice"],
        count: data["count"]
      }}
    end)
  end

  defp fetch_data("depth", params, endpoint, plug) do
    limit = Map.get(params, :limit, 20)
    Client.request(:get, api_path(endpoint, "/depth"), %{symbol: params.symbol, limit: limit}, endpoint: endpoint, plug: plug)
    |> handle_result(fn data ->
      {:ok, %{
        bids: data["bids"],
        asks: data["asks"],
        last_update_id: data["lastUpdateId"]
      }}
    end)
  end

  defp fetch_data("recent_trades", params, endpoint, plug) do
    limit = Map.get(params, :limit, 100)
    Client.request(:get, api_path(endpoint, "/trades"), %{symbol: params.symbol, limit: limit}, endpoint: endpoint, plug: plug)
    |> handle_result(fn trades ->
      formatted = Enum.map(trades, fn t ->
        %{
          id: t["id"],
          price: t["price"],
          qty: t["qty"],
          time: t["time"],
          is_buyer_maker: t["isBuyerMaker"]
        }
      end)
      {:ok, %{trades: formatted}}
    end)
  end

  defp fetch_data("klines", params, endpoint, plug) do
    limit = Map.get(params, :limit, 100)
    interval = Map.get(params, :interval, "1h")
    Client.request(:get, api_path(endpoint, "/klines"), %{
      symbol: params.symbol,
      interval: interval,
      limit: limit
    }, endpoint: endpoint, plug: plug)
    |> handle_result(fn klines ->
      formatted = Enum.map(klines, fn k ->
        %{
          open_time: Enum.at(k, 0),
          open: Enum.at(k, 1),
          high: Enum.at(k, 2),
          low: Enum.at(k, 3),
          close: Enum.at(k, 4),
          volume: Enum.at(k, 5),
          close_time: Enum.at(k, 6),
          quote_volume: Enum.at(k, 7),
          trades: Enum.at(k, 8)
        }
      end)
      {:ok, %{klines: formatted}}
    end)
  end

  defp fetch_data(type, _params, _endpoint, _plug) do
    {:error, "Unknown market data type: #{type}"}
  end

  defp api_path(:spot, suffix), do: "/api/v3" <> suffix
  defp api_path(:futures, suffix), do: "/fapi/v1" <> suffix

  defp parse_endpoint(%{endpoint: "futures"}), do: :futures
  defp parse_endpoint(_), do: :spot

  defp handle_result({:ok, data}, transform_fn), do: transform_fn.(data)
  defp handle_result({:error, _} = error, _), do: error
end
