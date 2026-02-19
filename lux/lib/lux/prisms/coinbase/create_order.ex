defmodule Lux.Prisms.Coinbase.CreateOrder do
  @moduledoc """
  A prism for creating orders on Coinbase Advanced Trade.

  Supports multiple order types:
  - **Market orders** - Execute immediately at the current market price
  - **Limit orders** (GTC) - Good till cancelled limit orders
  - **Limit orders** (GTD) - Good till date limit orders
  - **Stop limit orders** (GTC) - Stop limit with good till cancelled
  - **Stop limit orders** (GTD) - Stop limit with good till date

  ## Examples

      # Market buy order
      iex> Lux.Prisms.Coinbase.CreateOrder.handler(%{
      ...>   product_id: "BTC-USD",
      ...>   side: "BUY",
      ...>   order_configuration: %{
      ...>     market_market_ioc: %{
      ...>       quote_size: "100.00"
      ...>     }
      ...>   }
      ...> }, %{agent: %{name: "TradingAgent"}})
      {:ok, %{
        success: true,
        order_id: "abc-123",
        product_id: "BTC-USD",
        side: "BUY"
      }}

      # Limit order
      iex> Lux.Prisms.Coinbase.CreateOrder.handler(%{
      ...>   product_id: "BTC-USD",
      ...>   side: "BUY",
      ...>   order_configuration: %{
      ...>     limit_limit_gtc: %{
      ...>       base_size: "0.001",
      ...>       limit_price: "40000.00"
      ...>     }
      ...>   }
      ...> }, %{agent: %{name: "TradingAgent"}})
      {:ok, %{success: true, order_id: "def-456", ...}}
  """

  use Lux.Prism,
    name: "Coinbase Create Order",
    description: "Creates an order on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        client_order_id: %{
          type: :string,
          description: "Client-specified order ID (UUID format). Auto-generated if not provided."
        },
        product_id: %{
          type: :string,
          description: "The product ID for the order (e.g., BTC-USD)"
        },
        side: %{
          type: :string,
          description: "Order side",
          enum: ["BUY", "SELL"]
        },
        order_configuration: %{
          type: :object,
          description: "Order type configuration. Use one of the supported order types.",
          properties: %{
            market_market_ioc: %{
              type: :object,
              description: "Market order (Immediate or Cancel)",
              properties: %{
                quote_size: %{type: :string, description: "Amount in quote currency to spend"},
                base_size: %{type: :string, description: "Amount in base currency to buy/sell"}
              }
            },
            limit_limit_gtc: %{
              type: :object,
              description: "Limit order (Good Till Cancelled)",
              properties: %{
                base_size: %{type: :string, description: "Amount in base currency"},
                limit_price: %{type: :string, description: "Limit price"},
                post_only: %{type: :boolean, description: "Post-only order flag"}
              },
              required: ["base_size", "limit_price"]
            },
            limit_limit_gtd: %{
              type: :object,
              description: "Limit order (Good Till Date)",
              properties: %{
                base_size: %{type: :string, description: "Amount in base currency"},
                limit_price: %{type: :string, description: "Limit price"},
                end_time: %{type: :string, description: "Order expiry time (ISO 8601)"},
                post_only: %{type: :boolean, description: "Post-only order flag"}
              },
              required: ["base_size", "limit_price", "end_time"]
            },
            stop_limit_stop_limit_gtc: %{
              type: :object,
              description: "Stop-limit order (Good Till Cancelled)",
              properties: %{
                base_size: %{type: :string, description: "Amount in base currency"},
                limit_price: %{type: :string, description: "Limit price"},
                stop_price: %{type: :string, description: "Stop trigger price"},
                stop_direction: %{
                  type: :string,
                  description: "Stop trigger direction",
                  enum: ["STOP_DIRECTION_STOP_UP", "STOP_DIRECTION_STOP_DOWN"]
                }
              },
              required: ["base_size", "limit_price", "stop_price", "stop_direction"]
            },
            stop_limit_stop_limit_gtd: %{
              type: :object,
              description: "Stop-limit order (Good Till Date)",
              properties: %{
                base_size: %{type: :string, description: "Amount in base currency"},
                limit_price: %{type: :string, description: "Limit price"},
                stop_price: %{type: :string, description: "Stop trigger price"},
                stop_direction: %{
                  type: :string,
                  description: "Stop trigger direction",
                  enum: ["STOP_DIRECTION_STOP_UP", "STOP_DIRECTION_STOP_DOWN"]
                },
                end_time: %{type: :string, description: "Order expiry time (ISO 8601)"}
              },
              required: ["base_size", "limit_price", "stop_price", "stop_direction", "end_time"]
            }
          }
        }
      },
      required: ["product_id", "side", "order_configuration"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean, description: "Whether the order was successfully created"},
        order_id: %{type: :string, description: "The created order ID"},
        product_id: %{type: :string, description: "Product ID"},
        side: %{type: :string, description: "Order side"}
      },
      required: ["success"]
    }

  alias Lux.Integrations.Coinbase.Client

  require Logger

  @doc """
  Handles the request to create an order on Coinbase.
  """
  def handler(params, ctx) do
    agent_name = get_in(ctx, [:agent, :name]) || ctx[:name] || "Unknown Agent"

    with {:ok, product_id} <- validate_param(params, :product_id),
         {:ok, side} <- validate_param(params, :side),
         {:ok, order_config} <- validate_order_configuration(params) do
      client_order_id =
        Map.get(params, :client_order_id) || Lux.UUID.generate()

      body = %{
        client_order_id: client_order_id,
        product_id: product_id,
        side: side,
        order_configuration: order_config
      }

      Logger.info(
        "Agent #{agent_name} creating #{side} order for #{product_id}"
      )

      request_opts =
        if params[:plug], do: %{json: body, plug: params[:plug]}, else: %{json: body}

      case Client.request(:post, "/orders", request_opts) do
        {:ok, %{"success" => true} = response} ->
          Logger.info(
            "Successfully created order #{response["order_id"]} for #{product_id}"
          )

          {:ok, %{
            success: true,
            order_id: response["order_id"],
            product_id: product_id,
            side: side,
            client_order_id: client_order_id
          }}

        {:ok, %{"success" => false} = response} ->
          error = response["failure_reason"] || response["error_response"] || "Order creation failed"
          Logger.error("Failed to create order for #{product_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to create order for #{product_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_order_configuration(params) do
    case Map.fetch(params, :order_configuration) do
      {:ok, config} when is_map(config) ->
        valid_types = [
          :market_market_ioc,
          :limit_limit_gtc,
          :limit_limit_gtd,
          :stop_limit_stop_limit_gtc,
          :stop_limit_stop_limit_gtd,
          "market_market_ioc",
          "limit_limit_gtc",
          "limit_limit_gtd",
          "stop_limit_stop_limit_gtc",
          "stop_limit_stop_limit_gtd"
        ]

        has_valid_type = Enum.any?(valid_types, fn type -> Map.has_key?(config, type) end)

        if has_valid_type do
          {:ok, config}
        else
          {:error, "Invalid order configuration. Must include one of: market_market_ioc, limit_limit_gtc, limit_limit_gtd, stop_limit_stop_limit_gtc, stop_limit_stop_limit_gtd"}
        end

      _ ->
        {:error, "Missing order_configuration"}
    end
  end
end
