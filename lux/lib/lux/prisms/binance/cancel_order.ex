defmodule Lux.Prisms.Binance.CancelOrder do
  @moduledoc """
  A prism for canceling orders on Binance Spot or Futures networks.
  """

  use Lux.Prism,
    name: "Cancel Binance Order",
    description: "Cancels an open order on Binance Spot or Futures",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g. BTCUSDT)",
          pattern: "^[A-Z0-9-_.]{2,}$"
        },
        order_id: %{
          type: :string,
          description: "Binance Order ID to cancel"
        },
        network: %{
          type: :string,
          enum: ["spot", "futures"],
          description: "Network to use: spot or futures",
          default: "spot"
        }
      },
      required: ["symbol", "order_id"]
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
          description: "Order Status (CANCELED)"
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
      orderId: params.order_id
    }

    case Client.request(:delete, path, network: network, signed: true, params: api_params) do
      {:ok, %{"orderId" => order_id, "status" => status, "symbol" => symbol}} ->
        Logger.info("Successfully canceled Binance order #{order_id} on #{network}")
        {:ok, %{order_id: to_string(order_id), status: status, symbol: symbol}}
        
      {:error, {status, code, message}} ->
        error = "Binance API Error (#{status}) Code #{code}: #{message}"
        Logger.error("Failed to cancel order: #{error}")
        {:error, error}
        
      {:error, error} ->
        Logger.error("Failed to cancel order: #{inspect(error)}")
        {:error, inspect(error)}
    end
  end
end
