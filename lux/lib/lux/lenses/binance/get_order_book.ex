defmodule Lux.Lenses.Binance.GetOrderBook do
  @moduledoc """
  A lens for retrieving order book (depth) from Binance.
  Supports both Spot and Futures networks.
  """

  use Lux.Lens,
    name: "Binance Order Book",
    description: "Fetches market depth for a specific symbol on Binance Spot or Futures",
    url: "https://api.binance.com/api/v3/depth",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g. BTCUSDT)",
          pattern: "^[A-Z0-9-_.]{2,}$"
        },
        limit: %{
          type: :integer,
          description: "Limit of the order book. Default 100",
          default: 100
        },
        network: %{
          type: :string,
          enum: ["spot", "futures"],
          description: "The Binance network to use (spot or futures)",
          default: "spot"
        }
      },
      required: ["symbol"]
    }

  @impl true
  def before_focus(params, lens) do
    network = Map.get(params, :network, "spot")
    limit = Map.get(params, :limit, 100)
    
    url = case network do
      "futures" -> "https://fapi.binance.com/fapi/v1/depth"
      _ -> "https://api.binance.com/api/v3/depth"
    end

    params_for_req = %{
      symbol: String.upcase(params.symbol),
      limit: limit
    }
    
    {:ok, %{lens | url: url, params: params_for_req}}
  end

  @impl true
  def after_focus(%{"lastUpdateId" => _id, "bids" => bids, "asks" => asks}) do
    {:ok, %{
      bids: Enum.map(bids, fn [price, qty] -> %{price: price, quantity: qty} end),
      asks: Enum.map(asks, fn [price, qty] -> %{price: price, quantity: qty} end)
    }}
  end

  def after_focus(%{"msg" => msg, "code" => code}) do
    {:error, %{message: msg, code: code}}
  end
  
  def after_focus(error), do: {:error, error}
end
