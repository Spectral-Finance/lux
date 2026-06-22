defmodule Lux.Integrations.Web3.EventMonitor.WebSocket do
  @moduledoc """
  WebSocket client for live Smart Contract event monitoring.
  Connects to an EVM WebSocket RPC node (e.g., Infura, Alchemy) and subscribes to logs.
  """
  use WebSockex
  require Logger
  alias Lux.Integrations.Web3.EventMonitor.Storage

  @doc """
  Starts the WebSocket client and subscribes to events.
  
  ## Options
    * `:url` - The WebSocket RPC URL (required).
    * `:address` - Contract address to monitor (optional).
    * `:topics` - List of topics to filter (optional).
    * `:webhook_url` - Webhook URL for alerting (optional).
  """
  def start_link(opts) do
    url = Keyword.fetch!(opts, :url)
    state = %{
      address: Keyword.get(opts, :address),
      topics: Keyword.get(opts, :topics, []),
      webhook_url: Keyword.get(opts, :webhook_url),
      abi: Keyword.get(opts, :abi),
      subscription_id: nil
    }
    WebSockex.start_link(url, __MODULE__, state)
  end

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("[Lux.Web3.EventMonitor] Connected to WebSocket RPC.")
    
    # Subscribe to logs
    params = %{}
    params = if state.address, do: Map.put(params, :address, state.address), else: params
    params = if state.topics != [], do: Map.put(params, :topics, state.topics), else: params
    
    msg = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "eth_subscribe",
      "params" => ["logs", params]
    }
    
    {:reply, {:text, Jason.encode!(msg)}, state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, %{"id" => 1, "result" => sub_id}} ->
        Logger.info("[Lux.Web3.EventMonitor] Subscribed with ID: #{sub_id}")
        {:ok, %{state | subscription_id: sub_id}}
        
      {:ok, %{"method" => "eth_subscription", "params" => %{"result" => log}}} ->
        process_log(log, state)
        {:ok, state}
        
      {:ok, payload} ->
        Logger.debug("[Lux.Web3.EventMonitor] Received unhandled message: #{inspect(payload)}")
        {:ok, state}
        
      {:error, _} ->
        Logger.error("[Lux.Web3.EventMonitor] Failed to decode message: #{msg}")
        {:ok, state}
    end
  end

  @impl true
  def handle_disconnect(disconnect_map, state) do
    Logger.warning("[Lux.Web3.EventMonitor] Disconnected: #{inspect(disconnect_map)}")
    {:reconnect, state}
  end
  
  defp process_log(log, state) do
    # Try to decode if ABI is available
    decoded_log =
      if state.abi && log["data"] && log["topics"] && length(log["topics"]) > 0 do
        Lux.Integrations.Web3.EventMonitor.decode_log(log, state.abi)
      else
        log
      end

    # Store the log
    Storage.insert(decoded_log)
    
    # Fire webhook if configured
    if state.webhook_url do
      Task.start(fn -> 
        # Basic severity classification
        severity = if decoded_log["removed"], do: "warning", else: "info"
        
        case Req.post(state.webhook_url, json: %{event: decoded_log, severity: severity}) do
          {:ok, _res} -> Logger.info("[Lux.Web3.EventMonitor] Alert sent to webhook.")
          {:error, err} -> Logger.error("[Lux.Web3.EventMonitor] Webhook delivery failed: #{inspect(err)}")
        end
      end)
    end
  end
end
