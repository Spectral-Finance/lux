defmodule Lux.Prisms.Coinbase.ManageOrdersPrism do
  @moduledoc """
  A prism that manages orders on Coinbase Advanced Trade.

  Supports:
  - List open orders (with optional product_id filter)
  - Get a single order by ID
  - Cancel a single order
  - Cancel all orders (with optional product_id filter)
  - List fills

  Requires COINBASE_API_KEY and COINBASE_API_SECRET environment variables.

  ## Example - List Orders

      iex> Lux.Prisms.Coinbase.ManageOrdersPrism.run(%{
      ...>   action: :list_open_orders,
      ...>   product_id: "BTC-USD"
      ...> })

  ## Example - Cancel Order

      iex> Lux.Prisms.Coinbase.ManageOrdersPrism.run(%{
      ...>   action: :cancel_order,
      ...>   order_id: "abc-123-def"
      ...> })

  ## Example - Cancel All Orders

      iex> Lux.Prisms.Coinbase.ManageOrdersPrism.run(%{
      ...>   action: :cancel_all,
      ...>   product_id: "BTC-USD"
      ...> })
  """

  use Lux.Prism,
    name: "Coinbase Manage Orders",
    description: "List, retrieve, cancel orders and list fills on Coinbase",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "The action to perform",
          enum: ["list_open_orders", "get_order", "cancel_order", "cancel_all", "list_fills"]
        },
        order_id: %{
          type: :string,
          description: "Order ID (required for get_order and cancel_order)"
        },
        product_id: %{
          type: :string,
          description: "Product ID filter (optional for list_open_orders, cancel_all, list_fills)"
        },
        start_sequence: %{
          type: :integer,
          description: "Starting sequence number for fills (required for list_fills)"
        },
        end_sequence: %{
          type: :integer,
          description: "Ending sequence number for fills (required for list_fills)"
        },
        retail_portfolio_id: %{
          type: :string,
          description: "Retail portfolio ID filter"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        data: %{type: :object, description: "Action-specific response data"}
      }
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    python variables: %{input: input} do
      ~PY"""
      import os
      from coinbase.rest.orders import (
          list_open_orders, get_order, cancel_order, cancel_all, list_fills
      )

      api_key = os.getenv("COINBASE_API_KEY")
      api_secret = os.getenv("COINBASE_API_SECRET")

      if not api_key or not api_secret:
          raise ValueError("COINBASE_API_KEY and COINBASE_API_SECRET environment variables are required")

      from coinbase.rest.rest_base import RESTBase
      client = RESTBase(api_key=api_key, api_secret=api_secret)

      list_open_orders.__self__ = client
      get_order.__self__ = client
      cancel_order.__self__ = client
      cancel_all.__self__ = client
      list_fills.__self__ = client

      action = input.get("action")
      product_id = input.get("product_id")
      order_id = input.get("order_id")
      portfolio_id = input.get("retail_portfolio_id")

      result = {"action": action}

      if action == "list_open_orders":
          params = {}
          if product_id: params["product_id"] = product_id
          if portfolio_id: params["retail_portfolio_id"] = portfolio_id
          resp = list_open_orders(**params)
          result["data"] = resp.data if hasattr(resp, 'data') else resp

      elif action == "get_order":
          if not order_id:
              raise ValueError("order_id is required for get_order")
          params = {}
          if product_id: params["product_id"] = product_id
          if portfolio_id: params["retail_portfolio_id"] = portfolio_id
          resp = get_order(order_id, **params)
          result["data"] = resp.data if hasattr(resp, 'data') else resp

      elif action == "cancel_order":
          if not order_id:
              raise ValueError("order_id is required for cancel_order")
          params = {}
          if product_id: params["product_id"] = product_id
          if portfolio_id: params["retail_portfolio_id"] = portfolio_id
          resp = cancel_order(order_id, **params)
          result["data"] = resp.data if hasattr(resp, 'data') else resp
          result["cancelled"] = True

      elif action == "cancel_all":
          params = {}
          if product_id: params["product_id"] = product_id
          if portfolio_id: params["retail_portfolio_id"] = portfolio_id
          resp = cancel_all(**params)
          result["data"] = resp.data if hasattr(resp, 'data') else resp
          result["cancelled_all"] = True

      elif action == "list_fills":
          start_seq = input.get("start_sequence")
          end_seq = input.get("end_sequence")
          if not all([start_seq, end_seq]):
              raise ValueError("start_sequence and end_sequence are required for list_fills")
          params = {"start_sequence": start_seq, "end_sequence": end_seq}
          if product_id: params["product_id"] = product_id
          if portfolio_id: params["retail_portfolio_id"] = portfolio_id
          resp = list_fills(**params)
          result["data"] = resp.data if hasattr(resp, 'data') else resp

      else:
          raise ValueError(f"Unknown action: {action}")

      result
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
