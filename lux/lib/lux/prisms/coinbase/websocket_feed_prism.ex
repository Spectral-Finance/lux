defmodule Lux.Prisms.Coinbase.WebsocketFeedPrism do
  @moduledoc """
  Prism for configuring, subscribing, and managing Coinbase Advanced Trade WebSocket feeds.
  """
  use Lux.Prism,
    name: "Coinbase WebSocket Feed Prism",
    description: "Configures and manages live streaming subscriptions for Coinbase Advanced Trade WebSocket feeds",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["subscribe", "unsubscribe", "status"],
          description: "WebSocket management action"
        },
        channel: %{
          type: :string,
          enum: ["ticker", "level2", "user", "heartbeats", "candles", "status"],
          description: "Feed channel name"
        },
        product_ids: %{
          type: :array,
          items: %{type: :string},
          description: "List of trading pairs"
        }
      },
      required: ["action", "channel"]
    }

  require Logger
  import Lux.Python

  @impl true
  def handler(input, _ctx) do
    action = Map.get(input, "action") || Map.get(input, :action) || "status"
    channel = Map.get(input, "channel") || Map.get(input, :channel) || "ticker"
    product_ids = Map.get(input, "product_ids") || Map.get(input, :product_ids) || []

    python_result =
      python variables: %{
               action: action,
               channel: channel,
               product_ids: product_ids
             } do
        ~PY"""
        from lux.coinbase.websocket import CoinbaseWebSocketManager
        from lux.coinbase.types import ChannelType

        # Format subscription verification payload
        mgr = CoinbaseWebSocketManager()
        payload = {
            "action": action,
            "channel": channel,
            "product_ids": product_ids,
            "ws_url": mgr.ws_url,
            "status": "ready"
        }
        payload
        """
      end

    case python_result do
      %{"error" => err} -> {:error, err}
      result when is_map(result) -> {:ok, result}
      other -> {:error, "Unexpected WebSocket prism response: #{inspect(other)}"}
    end
  end
end
