defmodule Lux.Prisms.Coinbase.CreateOrderPrism do
  @moduledoc """
  A prism that creates orders on Coinbase Advanced Trade.

  Supports market orders, limit orders (GTC/GTD/FOK/IOC), and stop-limit orders.

  ## Example - Market Buy

      iex> Lux.Prisms.Coinbase.CreateOrderPrism.run(%{
      ...>   product_id: "BTC-USD",
      ...>   side: "BUY",
      ...>   order_configuration: %{
      ...>     market_order_config: %{}
      ...>   },
      ...>   quote_size: "100"
      ...> })
      {:ok, %{order_id: "...", status: "CREATED"}}

  ## Example - Limit Order

      iex> Lux.Prisms.Coinbase.CreateOrderPrism.run(%{
      ...>   product_id: "ETH-USD",
      ...>   side: "SELL",
      ...>   order_configuration: %{
      ...>     limit_order_gtc: %{
      ...>       base_size: "0.1",
      ...>       limit_price: "2000.00"
      ...>     }
      ...>   }
      ...> })

  Requires COINBASE_API_KEY and COINBASE_API_SECRET environment variables.
  """

  use Lux.Prism,
    name: "Coinbase Create Order",
    description: "Creates market, limit (GTC/GTD/FOK/IOC), or stop-limit orders on Coinbase",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Product identifier (e.g., 'BTC-USD')"
        },
        side: %{
          type: :string,
          description: "BUY or SELL",
          enum: ["BUY", "SELL"]
        },
        order_configuration: %{
          type: :object,
          description: "Order configuration - one of market_order_config, limit_order_gtc, limit_order_gtd, limit_order_fok, limit_order_ioc, or stop_limit_limit_gtc",
          oneOf: [
            %{
              type: :object,
              properties: %{
                market_order_config: %{type: :object}
              },
              required: ["market_order_config"]
            },
            %{
              type: :object,
              properties: %{
                limit_order_gtc: %{
                  type: :object,
                  properties: %{
                    base_size: %{type: :string},
                    limit_price: %{type: :string}
                  },
                  required: ["base_size", "limit_price"]
                }
              },
              required: ["limit_order_gtc"]
            },
            %{
              type: :object,
              properties: %{
                limit_order_gtd: %{
                  type: :object,
                  properties: %{
                    base_size: %{type: :string},
                    limit_price: %{type: :string},
                    end_time: %{type: :string}
                  },
                  required: ["base_size", "limit_price", "end_time"]
                }
              },
              required: ["limit_order_gtd"]
            },
            %{
              type: :object,
              properties: %{
                limit_order_fok: %{
                  type: :object,
                  properties: %{
                    base_size: %{type: :string},
                    limit_price: %{type: :string}
                  },
                  required: ["base_size", "limit_price"]
                }
              },
              required: ["limit_order_fok"]
            },
            %{
              type: :object,
              properties: %{
                limit_order_ioc: %{
                  type: :object,
                  properties: %{
                    base_size: %{type: :string},
                    limit_price: %{type: :string}
                  },
                  required: ["base_size", "limit_price"]
                }
              },
              required: ["limit_order_ioc"]
            },
            %{
              type: :object,
              properties: %{
                stop_limit_limit_gtc: %{
                  type: :object,
                  properties: %{
                    trigger_price: %{type: :string},
                    limit_price: %{type: :string},
                    base_size: %{type: :string},
                    side: %{type: :string}
                  },
                  required: ["trigger_price", "limit_price", "base_size", "side"]
                }
              },
              required: ["stop_limit_limit_gtc"]
            }
          ]
        },
        client_order_id: %{
          type: :string,
          description: "Custom order ID (auto-generated if omitted)"
        },
        retail_portfolio_id: %{
          type: :string,
          description: "Portfolio UUID for retail portfolios"
        }
      },
      required: ["product_id", "side", "order_configuration"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        order_id: %{type: :string, description: "Coinbase order ID"},
        status: %{type: :string, description: "Order status"},
        product_id: %{type: :string},
        side: %{type: :string},
        message: %{type: :string, description: "Success or error message"}
      }
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    python variables: %{input: input} do
      ~PY"""
      import os
      import uuid
      from coinbase.rest.orders import create_order

      api_key = os.getenv("COINBASE_API_KEY")
      api_secret = os.getenv("COINBASE_API_SECRET")

      if not api_key or not api_secret:
          raise ValueError("COINBASE_API_KEY and COINBASE_API_SECRET environment variables are required")

      from coinbase.rest.rest_base import RESTBase
      client = RESTBase(api_key=api_key, api_secret=api_secret)
      create_order.__self__ = client

      product_id = input.get("product_id")
      side = input.get("side")
      order_config = input.get("order_configuration")

      if not all([product_id, side, order_config]):
          missing = [k for k, v in [("product_id", product_id), ("side", side), ("order_config", order_config)] if not v]
          raise ValueError(f"Missing required fields: {', '.join(missing)}")

      if side not in ["BUY", "SELL"]:
          raise ValueError("side must be BUY or SELL")

      client_order_id = input.get("client_order_id", uuid.uuid4().hex)
      portfolio_id = input.get("retail_portfolio_id")

      data = {
          "client_order_id": client_order_id,
          "product_id": product_id,
          "side": side,
          "order_configuration": order_config,
      }
      if portfolio_id:
          data["retail_portfolio_id"] = portfolio_id

      response = create_order(**data)
      resp_data = response.data if hasattr(response, 'data') else response

      {
          "order_id": resp_data.get("order_id") if isinstance(resp_data, dict) else None,
          "status": resp_data.get("status") if isinstance(resp_data, dict) else "CREATED",
          "product_id": product_id,
          "side": side,
          "message": "Order created successfully"
      }
      """
    end
    |> handle_python_result()
  end

  defp handle_python_result(result) when is_map(result) do
    case Map.get(result, "error") do
      nil -> {:ok, result}
      err when is_binary(err) -> {:error, err}
      _ -> {:ok, result}
    end
  end

  defp handle_python_result({:error, error}) do
    {:error, error}
  end
end
