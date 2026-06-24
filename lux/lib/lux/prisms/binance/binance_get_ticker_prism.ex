defmodule Lux.Prisms.Binance.GetTickerPrism do
  @moduledoc """
  A prism for retrieving real-time ticker price information from Binance.

  Supports both spot and futures markets.

  ## Examples

      iex> Lux.Prisms.Binance.GetTickerPrism.handler(%{symbol: "BTCUSDT"}, %{name: "Agent"})
      {:ok, %{
        symbol: "BTCUSDT",
        price: "65432.10",
        price_change: "1234.56",
        price_change_percent: "1.92",
        volume: "28765.432",
        quote_volume: "1876543210.00",
        high: "66000.00",
        low: "63500.00",
        open: "64197.54"
      }}
  """

  use Lux.Prism,
    name: "Binance Get Ticker",
    description: "Retrieves 24hr ticker price change statistics for a symbol on Binance",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT', 'ETHUSDT')",
          pattern: "^[A-Z0-9]{2,20}$"
        },
        futures: %{
          type: :boolean,
          description: "If true, query the Futures market instead of Spot",
          default: false
        }
      },
      required: ["symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair symbol"},
        price: %{type: :string, description: "Latest price"},
        price_change: %{type: :string, description: "Price change in 24h"},
        price_change_percent: %{type: :string, description: "Price change percent in 24h"},
        volume: %{type: :string, description: "Base asset volume in 24h"},
        quote_volume: %{type: :string, description: "Quote asset volume in 24h"},
        high: %{type: :string, description: "24h high price"},
        low: %{type: :string, description: "24h low price"},
        open: %{type: :string, description: "24h open price"}
      },
      required: ["symbol", "price"]
    }

  alias Lux.Integrations.Binance
  require Logger

  @doc """
  Handles the request to get ticker information from Binance.
  """
  def handler(%{symbol: symbol} = params, agent) do
    futures = Map.get(params, :futures, false)
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching ticker for #{symbol} (futures: #{futures})")

    path = if futures, do: "/fapi/v1/ticker/24hr", else: "/api/v3/ticker/24hr"

    case Binance.get(path, %{symbol: symbol}, futures: futures) do
      {:ok, %{"symbol" => sym, "lastPrice" => price} = data} ->
        result = %{
          symbol: sym,
          price: price,
          price_change: data["priceChange"],
          price_change_percent: data["priceChangePercent"],
          volume: data["volume"],
          quote_volume: data["quoteVolume"],
          high: data["highPrice"],
          low: data["lowPrice"],
          open: data["openPrice"]
        }
        Logger.info("Successfully fetched ticker for #{symbol}: #{price}")
        {:ok, result}

      {:error, {status, %{"msg" => msg}}} ->
        Logger.error("Binance ticker error for #{symbol}: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Binance ticker request failed for #{symbol}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
