defmodule Lux.Integrations.Coinbase.WebSocket do
  @moduledoc """
  WebSocket client for Coinbase Advanced Trade data streams.
  """

  use WebSockex
  require Logger

  @ws_url "wss://advanced-trade-ws.coinbase.com"

  @doc """
  Starts a WebSocket connection to Coinbase Advanced Trade.

  ## Options
    * `:channels` - List of channels to subscribe to (e.g. ["level2", "ticker"])
    * `:product_ids` - List of product IDs (e.g. ["BTC-USD", "ETH-USD"])
    * `:handler` - The PID or a function `fn msg -> ... end` to handle incoming parsed JSON messages.
  """
  def start_link(opts) do
    handler = Keyword.get(opts, :handler, self())
    channels = Keyword.get(opts, :channels, [])
    product_ids = Keyword.get(opts, :product_ids, [])

    state = %{
      handler: handler,
      channels: channels,
      product_ids: product_ids
    }

    case WebSockex.start_link(@ws_url, __MODULE__, state) do
      {:ok, pid} ->
        if not Enum.empty?(channels) and not Enum.empty?(product_ids) do
          subscribe(pid, channels, product_ids)
        end

        {:ok, pid}

      error ->
        error
    end
  end

  @doc """
  Subscribes to channels for specific products.
  """
  def subscribe(pid, channels, product_ids) when is_list(channels) and is_list(product_ids) do
    msg = %{
      "type" => "subscribe",
      # In advanced trade, usually one channel per message
      "channel" => hd(channels),
      "product_ids" => product_ids
    }

    # Advanced trade requires signature for authenticated channels like "user"
    # For public channels like "ticker", "level2", "market_trades", signature is optional but recommended

    api_key = Application.get_env(:lux, :api_keys)[:coinbase_api_key]
    api_secret = Application.get_env(:lux, :api_keys)[:coinbase_api_secret]

    msg =
      if api_key && api_secret do
        timestamp = System.os_time(:second) |> Integer.to_string()
        message = timestamp <> msg["channel"] <> Enum.join(product_ids, ",")

        signature =
          :crypto.mac(:hmac, :sha256, api_secret, message) |> Base.encode16(case: :lower)

        Map.merge(msg, %{
          "api_key" => api_key,
          "timestamp" => timestamp,
          "signature" => signature
        })
      else
        msg
      end

    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  @doc """
  Unsubscribes from channels.
  """
  def unsubscribe(pid, channels, product_ids) when is_list(channels) and is_list(product_ids) do
    msg = %{
      "type" => "unsubscribe",
      "channel" => hd(channels),
      "product_ids" => product_ids
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded} ->
        notify_handler(state.handler, decoded)

      {:error, _} ->
        Logger.warning("Failed to decode Coinbase WS message: #{msg}")
    end

    {:ok, state}
  end

  @impl true
  def handle_disconnect(disconnect_map, state) do
    Logger.warning("Coinbase WS disconnected: #{inspect(disconnect_map)}")
    {:reconnect, state}
  end

  defp notify_handler(pid, msg) when is_pid(pid) do
    send(pid, {:coinbase_ws_msg, msg})
  end

  defp notify_handler(fun, msg) when is_function(fun, 1) do
    fun.(msg)
  end
end
