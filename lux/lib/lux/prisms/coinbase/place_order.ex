defmodule Lux.Prisms.Coinbase.PlaceOrder do
  @moduledoc """
  A prism for placing orders on Coinbase Advanced Trade.
  """

  use Lux.Prism,
    name: "Coinbase Place Order",
    description: "Places a trading order on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :string, description: "Trading pair (e.g., BTC-USD)"},
        side: %{type: :string, description: "BUY or SELL"},
        type: %{type: :string, description: "Order type (LIMIT, MARKET)"},
        quantity: %{type: :string, description: "Quantity to order"},
        price: %{type: :string, description: "Price for LIMIT orders (optional)"}
      },
      required: ["product_id", "side", "type", "quantity"]
    }

  alias Lux.Integrations.Coinbase.Client

  @impl true
  def handler(params, _ctx) do
    path = "/api/v3/brokerage/orders"
    client_order_id = System.unique_integer([:positive]) |> to_string()

    order_config =
      case String.upcase(params.type) do
        "LIMIT" ->
          %{
            "limit_limit_gtc" => %{
              "base_size" => params.quantity,
              "limit_price" => params.price,
              "post_only" => false
            }
          }

        "MARKET" ->
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

    case Client.request(:post, path, signed: true, json: api_params) do
      {:ok, response} ->
        {:ok, response}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end
end
