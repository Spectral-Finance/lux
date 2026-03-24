defmodule Lux.Prisms.Coinbase.CoinbaseWebSocketPrism do
  @moduledoc """
  A prism for WebSocket subscriptions to Coinbase Exchange real-time data.

  ## Example

      # Subscribe to ticker updates
      iex> Lux.Prisms.Coinbase.CoinbaseWebSocketPrism.run(%{
      ...>   action: "subscribe",
      ...>   channels: ["ticker"],
      ...>   product_ids: ["BTC-USD", "ETH-USD"]
      ...> })
      {:ok, %{status: "success", message: "Subscription setup prepared"}}

      # Subscribe to order updates (requires authentication)
      iex> Lux.Prisms.Coinbase.CoinbaseWebSocketPrism.run(%{
      ...>   action: "subscribe",
      ...>   channels: ["user"],
      ...>   product_ids: ["BTC-USD"]
      ...> })

      # Subscribe to level2 order book
      iex> Lux.Prisms.Coinbase.CoinbaseWebSocketPrism.run(%{
      ...>   action: "subscribe",
      ...>   channels: ["level2"],
      ...>   product_ids: ["BTC-USD"]
      ...> })

  ## Available Channels

  - `heartbeat` - Heartbeat messages
  - `ticker` - Ticker updates
  - `level2` - Level 2 order book updates
  - `matches` - Match updates
  - `user` - User order updates (requires authentication)
  - `full` - Full order book updates

  The prism reads authentication details from configuration:
  - :coinbase_api_key - Coinbase API key
  - :coinbase_api_secret - Coinbase API secret (base64 encoded)
  - :coinbase_api_passphrase - Coinbase API passphrase
  """

  use Lux.Prism,
    name: "Coinbase WebSocket",
    description: "Manages WebSocket subscriptions for Coinbase Exchange",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "WebSocket action",
          enum: ["subscribe", "unsubscribe", "get_status"]
        },
        channels: %{
          type: :array,
          items: %{type: :string},
          description: "Channels to subscribe/unsubscribe"
        },
        product_ids: %{
          type: :array,
          items: %{type: :string},
          description: "Product IDs (e.g., ['BTC-USD', 'ETH-USD'])"
        },
        authenticate: %{
          type: :boolean,
          description: "Whether to authenticate the connection",
          default: false
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        subscriptions: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              channel: %{type: :string},
              product_ids: %{type: :array, items: %{type: :string}}
            }
          }
        },
        message: %{type: :string},
        error: %{type: :string}
      },
      required: ["status"]
    }

  import Lux.Python

  alias Lux.Config

  require Lux.Python

  def handler(input, _ctx) do
    action = Map.get(input, "action", Map.get(input, :action, "get_status"))

    with {:ok, api_key} <- get_optional_api_key(),
         {:ok, api_secret} <- get_optional_api_secret(),
         {:ok, passphrase} <- get_optional_passphrase(),
         {:ok, ws_url} <- {:ok, Config.coinbase_ws_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("coinbase_utils.setup"),
         {:ok, result} <- handle_websocket_action(api_key, api_secret, passphrase, ws_url, action, input) do
      {:ok, result}
    else
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, reason} ->
        {:error, "Failed to handle WebSocket action: #{inspect(reason)}"}
    end
  end

  defp get_optional_api_key do
    {:ok, Config.coinbase_api_key()}
  rescue
    RuntimeError -> {:ok, nil}
  end

  defp get_optional_api_secret do
    {:ok, Config.coinbase_api_secret()}
  rescue
    RuntimeError -> {:ok, nil}
  end

  defp get_optional_passphrase do
    {:ok, Config.coinbase_api_passphrase()}
  rescue
    RuntimeError -> {:ok, nil}
  end

  defp handle_websocket_action(api_key, api_secret, passphrase, ws_url, "subscribe", params) do
    python_result =
      python variables: %{
               api_key: api_key,
               api_secret: api_secret,
               passphrase: passphrase,
               ws_url: ws_url,
               params: params
             } do
        ~PY"""
        from coinbase_utils.setup import CoinbaseWebSocket
        import json

        channels = params.get("channels", [])
        product_ids = params.get("product_ids", [])
        authenticate = params.get("authenticate", False)

        # Return subscription configuration
        # The actual WebSocket connection should be managed externally
        subscriptions = []
        for channel in channels:
            subscriptions.append({
                "channel": channel,
                "product_ids": product_ids
            })

        # Generate subscribe messages
        if api_key and api_secret and passphrase and authenticate:
            ws = CoinbaseWebSocket(api_key, api_secret, passphrase, ws_url)
            messages = []
            for channel in channels:
                msg = ws._get_subscribe_message(channel, product_ids, auth=True)
                messages.append(msg)
            {
                "status": "success",
                "message": "WebSocket subscription messages prepared",
                "subscriptions": subscriptions,
                "subscribe_messages": messages
            }
        else:
            # Public subscription
            messages = []
            for channel in channels:
                messages.append({
                    "type": "subscribe",
                    "channel": channel,
                    "product_ids": product_ids
                })
            {
                "status": "success",
                "message": "WebSocket subscription messages prepared",
                "subscriptions": subscriptions,
                "subscribe_messages": messages
            }
        """
      end

    case python_result do
      %{"status" => "success"} = result -> {:ok, result}
      %{"error" => error} -> {:error, error}
    end
  end

  defp handle_websocket_action(_api_key, _api_secret, _passphrase, _ws_url, "get_status", _params) do
    {:ok, %{
      status: "success",
      message: "WebSocket integration ready",
      ws_url: "wss://ws-feed.exchange.coinbase.com",
      available_channels: ["heartbeat", "ticker", "level2", "matches", "user", "full"]
    }}
  end

  defp handle_websocket_action(_api_key, _api_secret, _passphrase, _ws_url, action, _params) do
    {:error, "Unknown action: #{action}"}
  end
end