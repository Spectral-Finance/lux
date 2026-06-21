defmodule Lux.Prisms.Binance.PlaceOrder do
  @moduledoc """
  A prism for placing orders on Binance Spot or Futures networks.
  """

  use Lux.Prism,
    name: "Place Binance Order",
    description: "Places a market or limit order on Binance Spot or Futures",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g. BTCUSDT)",
          pattern: "^[A-Z0-9-_.]{2,}$"
        },
        side: %{
          type: :string,
          enum: ["BUY", "SELL"],
          description: "Order side: BUY or SELL"
        },
        type: %{
          type: :string,
          enum: ["LIMIT", "MARKET"],
          description: "Order type: LIMIT or MARKET"
        },
        quantity: %{
          type: :number,
          description: "Quantity to buy/sell"
        },
        price: %{
          type: :number,
          description: "Price for LIMIT orders"
        },
        network: %{
          type: :string,
          enum: ["spot", "futures"],
          description: "Network to use: spot or futures",
          default: "spot"
        }
      },
      required: ["symbol", "side", "type", "quantity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        order_id: %{
          type: :string,
          description: "Binance Order ID"
        },
        status: %{
          type: :string,
          description: "Order Status"
        },
        symbol: %{
          type: :string,
          description: "Trading pair symbol"
        }
      },
      required: ["order_id", "status"]
    }

  alias Lux.Integrations.Binance.Client
  require Logger

  @impl true
  def handler(params, _agent) do
    network = String.to_atom(Map.get(params, :network, "spot"))
    
    path = case network do
      :spot -> "/api/v3/order"
      :futures -> "/fapi/v1/order"
    end

    api_params = %{
      symbol: String.upcase(params.symbol),
      side: String.upcase(params.side),
      type: String.upcase(params.type),
      quantity: params.quantity
    }

    api_params = if String.upcase(params.type) == "LIMIT" do
      api_params
      |> Map.put(:price, params.price)
      |> Map.put(:timeInForce, "GTC")
    else
      api_params
    end

    case Client.request(:post, path, network: network, signed: true, params: api_params) do
      {:ok, %{"orderId" => order_id, "status" => status, "symbol" => symbol}} ->
        Logger.info("Successfully placed Binance order #{order_id} on #{network}")
        {:ok, %{order_id: to_string(order_id), status: status, symbol: symbol}}
        
      {:error, {status, code, message}} ->
        error = "Binance API Error (#{status}) Code #{code}: #{message}"
        Logger.error("Failed to place order: #{error}")
        {:error, error}
        
      {:error, error} ->
        Logger.error("Failed to place order: #{inspect(error)}")
        {:error, inspect(error)}
    end
  end
end
