defmodule Lux.Prisms.Coinbase.WSMarketStreamPrism do
  @moduledoc """
  A prism that subscribes to real-time WebSocket market data streams from Coinbase.

  Supports subscribing to public channels:
  - heartbeats
  - candles
  - market_trades
  - status
  - ticker
  - ticker_batch
  - level2

  Requires COINBASE_API_KEY and COINBASE_API_SECRET environment variables
  for authenticated channels (user, futures_balance_summary).

  ## Example - Subscribe to Ticker Channel

      iex> Lux.Prisms.Coinbase.WSMarketStreamPrism.run(%{
      ...>   action: "subscribe",
      ...>   channels: ["ticker"],
      ...>   product_ids: ["BTC-USD", "ETH-USD"]
      ...> })
      {:ok, %{subscribed: true, channels: ["ticker"], product_ids: ["BTC-USD", "ETH-USD"]}}

  ## Example - Unsubscribe

      iex> Lux.Prisms.Coinbase.WSMarketStreamPrism.run(%{
      ...>   action: "unsubscribe",
      ...>   channels: ["ticker"],
      ...>   product_ids: ["BTC-USD"]
      ...> })
  """

  use Lux.Prism,
    name: "Coinbase WebSocket Market Stream",
    description: "Subscribe/unsubscribe to real-time Coinbase WebSocket market data channels",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "The action to perform",
          enum: ["subscribe", "unsubscribe", "subscribe_all", "get_subscriptions", "get_status"]
        },
        channels: %{
          type: :array,
          description: "List of channels to subscribe/unsubscribe to",
          items: %{type: :string},
          enum: [
            "heartbeats", "candles", "market_trades", "status", "ticker",
            "ticker_batch", "level2", "user", "futures_balance_summary"
          ]
        },
        product_ids: %{
          type: :array,
          description: "List of product IDs to subscribe to",
          items: %{type: :string}
        },
        heartbeat_interval_seconds: %{
          type: :integer,
          description: "Interval for heartbeat messages (default: 5)"
        },
        ws_url: %{
          type: :string,
          description: "Custom WebSocket URL (defaults to public or user URL)"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        success: %{type: :boolean},
        channels: %{type: :array},
        product_ids: %{type: :array},
        subscriptions: %{type: :object, description: "Current subscriptions map"},
        message: %{type: :string}
      }
    }

  import Lux.Python
  require Lux.Python

  def handler(input, _ctx) do
    python variables: %{input: input} do
      ~PY"""
      import os
      import json
      import time
      import threading
      from coinbase.websocket.channels import Channels
      from coinbase.websocket.websocket_base import WSBase, WSClientException, WSClientConnectionClosedException

      api_key = os.getenv("COINBASE_API_KEY", "")
      api_secret = os.getenv("COINBASE_API_SECRET", "")

      action = input.get("action")
      channels = input.get("channels", [])
      product_ids = input.get("product_ids", [])

      result = {"action": action}

      # Determine base URL
      ws_url = input.get("ws_url")
      if not ws_url:
          # Check if any channel requires auth
          auth_channels = {"user", "futures_balance_summary"}
          has_auth = bool(set(channels) & auth_channels) if channels else False
          ws_url = "wss://advanced-trade-ws-user.coinbase.com" if has_auth else "wss://advanced-trade-ws.coinbase.com"

      messages_received = []

      def on_message(msg):
          messages_received.append(msg)

      def on_open():
          pass

      def on_close():
          pass

      try:
          ws = WSBase(
              api_key=api_key if api_key else None,
              api_secret=api_secret if api_secret else None,
              base_url=ws_url,
              on_message=on_message,
              on_open=on_open,
              on_close=on_close,
              retry=True
          )

          if action == "subscribe":
              if not channels or not product_ids:
                  raise ValueError("channels and product_ids are required for subscribe")
              ws.open()
              # Small delay to ensure connection is established
              time.sleep(0.5)
              ws.subscribe(product_ids, channels)
              result["success"] = True
              result["message"] = f"Subscribed to {channels} for {product_ids}"

          elif action == "unsubscribe":
              if not channels or not product_ids:
                  raise ValueError("channels and product_ids are required for unsubscribe")
              ws.open()
              time.sleep(0.5)
              ws.unsubscribe(product_ids, channels)
              result["success"] = True
              result["message"] = f"Unsubscribed from {channels} for {product_ids}"

          elif action == "subscribe_all":
              # Subscribe to all available public channels
              public_channels = ["heartbeats", "candles", "market_trades", "status", "ticker", "ticker_batch", "level2"]
              ws.open()
              time.sleep(0.5)
              for ch in public_channels:
                  ws.subscribe(product_ids or ["BTC-USD"], [ch])
              result["success"] = True
              result["message"] = f"Subscribed to all public channels"

          elif action == "get_subscriptions":
              result["subscriptions"] = ws.subscriptions if hasattr(ws, 'subscriptions') else {}
              result["success"] = True

          elif action == "get_status":
              ws.open()
              time.sleep(0.5)
              result["connected"] = True
              result["subscriptions"] = ws.subscriptions if hasattr(ws, 'subscriptions') else {}
              result["success"] = True

          else:
              raise ValueError(f"Unknown action: {action}")

      except WSClientException as e:
          result["success"] = False
          result["error"] = str(e)
      except Exception as e:
          result["success"] = False
          result["error"] = str(e)

      # Include any received messages (up to 10)
      result["messages"] = messages_received[:10]

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
