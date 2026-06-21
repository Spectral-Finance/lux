defmodule Lux.Prisms.Coinbase.PlaceOrder do
  @moduledoc """
  A prism for placing orders on Coinbase Advanced Trade.
  """

  use Lux.Prism,
    name: "Place Coinbase Order",
    description: "Places a market or limit order on Coinbase",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Trading pair symbol (e.g. BTC-USD)",
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
          type: :string,
          description: "Quantity to buy/sell (as string)"
        },
        price: %{
          type: :string,
          description: "Price for LIMIT orders (as string)"
        }
      },
      required: ["product_id", "side", "type", "quantity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        order_id: %{
          type: :string,
          description: "Coinbase Order ID"
        },
        success: %{
          type: :boolean,
          description: "Order success status"
        }
      },
      required: ["order_id", "success"]
    }

  alias Lux.Integrations.Coinbase.Client
  require Logger

  @impl true
  def handler(params, _agent) do
    client_order_id = :crypto.strong_rand_bytes(16) |> Base.encode16()

    order_config = if String.upcase(params.type) == "LIMIT" do
      %{
        "limit_limit_gtc" => %{
          "base_size" => params.quantity,
          "limit_price" => params.price,
          "post_only" => false
        }
      }
    else
      if String.upcase(params.side) == "BUY" do
        %{
          "market_market_ioc" => %{
            "quote_size" => params.quantity
          }
        }
      else
        %{
          "market_market_ioc" => %{
            "base_size" => params.quantity
          }
        }
      end
    end

    api_params = %{
      "client_order_id" => client_order_id,
      "product_id" => String.upcase(params.product_id),
      "side" => String.upcase(params.side),
      "order_configuration" => order_config
    }

    case Client.request(:post, "/api/v3/brokerage/orders", signed: true, json: api_params) do
      {:ok, %{"success" => true, "success_response" => %{"order_id" => order_id}}} ->
        Logger.info("Successfully placed Coinbase order #{order_id}")
        {:ok, %{order_id: to_string(order_id), success: true}}
        
      {:ok, %{"success" => false, "error_response" => %{"message" => message}}} ->
        Logger.error("Failed to place order: #{message}")
        {:error, message}

      {:error, {status, body}} ->
        error = "Coinbase API Error (#{status}): #{inspect(body)}"
        Logger.error("Failed to place order: #{error}")
        {:error, error}
        
      {:error, error} ->
        Logger.error("Failed to place order: #{inspect(error)}")
        {:error, inspect(error)}
    end
  end
end
