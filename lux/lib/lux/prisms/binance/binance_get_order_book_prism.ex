defmodule Lux.Prisms.Binance.GetOrderBookPrism do
  @moduledoc """
  A prism for retrieving the order book (depth of market) from Binance.

  ## Examples

      iex> Lux.Prisms.Binance.GetOrderBookPrism.handler(%{symbol: "BTCUSDT", limit: 5}, %{name: "Agent"})
      {:ok, %{
        symbol: "BTCUSDT",
        bids: [["65000.00", "0.5"], ...],
        asks: [["65001.00", "0.3"], ...],
        last_update_id: 123456789
      }}
  """

  use Lux.Prism,
    name: "Binance Get Order Book",
    description: "Retrieves the order book depth for a symbol on Binance",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT')"
        },
        limit: %{
          type: :integer,
          description: "Number of price levels to retrieve (5, 10, 20, 50, 100, 500, 1000)",
          default: 20,
          enum: [5, 10, 20, 50, 100, 500, 1000]
        },
        futures: %{
          type: :boolean,
          description: "If true, query Futures market",
          default: false
        }
      },
      required: ["symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair symbol"},
        bids: %{type: :array, description: "List of [price, quantity] bid entries"},
        asks: %{type: :array, description: "List of [price, quantity] ask entries"},
        last_update_id: %{type: :integer, description: "Last order book update ID"}
      },
      required: ["symbol", "bids", "asks"]
    }

  alias Lux.Integrations.Binance
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    futures = Map.get(params, :futures, false)
    limit = Map.get(params, :limit, 20)

    Logger.info("Agent #{agent_name} fetching order book for #{params.symbol}")

    path = if futures, do: "/fapi/v1/depth", else: "/api/v3/depth"

    case Binance.get(path, %{symbol: params.symbol, limit: limit}, futures: futures) do
      {:ok, %{"bids" => bids, "asks" => asks, "lastUpdateId" => last_update_id}} ->
        Logger.info("Order book fetched: #{length(bids)} bids, #{length(asks)} asks")
        {:ok, %{symbol: params.symbol, bids: bids, asks: asks, last_update_id: last_update_id}}

      {:error, {status, %{"msg" => msg}}} ->
        Logger.error("Binance order book error: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Order book request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
