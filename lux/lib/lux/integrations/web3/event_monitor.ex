defmodule Lux.Integrations.Web3.EventMonitor do
  @moduledoc """
  Top level integration module for Smart Contract Event Monitoring.
  Orchestrates storage, WebSocket real-time subscription, and historical syncing.
  """
  
  alias Lux.Integrations.Web3.EventMonitor.Storage
  alias Lux.Integrations.Web3.EventMonitor.WebSocket
  
  @doc """
  Starts a real-time event monitor.
  Returns the PID of the WebSocket client.
  
  ## Options
    * `:url` - The WebSocket RPC URL (required).
    * `:address` - Contract address to filter logs (optional).
    * `:topics` - List of topic strings to filter logs (optional).
    * `:webhook_url` - Webhook URL for alerting (optional).
  """
  def start_monitor(opts) do
    WebSocket.start_link(opts)
  end
  
  @doc """
  Fetches historical events for a given block range using HTTP RPC (eth_getLogs).
  Stores the results into `Storage` so they can be queried alongside live events.
  
  ## Options
    * `:url` - The HTTP RPC URL (required).
    * `:address` - Contract address to filter logs (optional).
    * `:topics` - List of topic strings to filter logs (optional).
    * `:from_block` - Hex string or tags like "earliest" (optional).
    * `:to_block` - Hex string or tags like "latest" (optional).
  """
  def sync_historical(opts) do
    url = Keyword.fetch!(opts, :url)
    
    params = %{
      "fromBlock" => Keyword.get(opts, :from_block, "earliest"),
      "toBlock" => Keyword.get(opts, :to_block, "latest")
    }
    
    params = if opts[:address], do: Map.put(params, "address", opts[:address]), else: params
    params = if opts[:topics], do: Map.put(params, "topics", opts[:topics]), else: params
    
    payload = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "eth_getLogs",
      "params" => [params]
    }
    
    case Req.post(url, json: payload) do
      {:ok, %Req.Response{body: %{"result" => logs}}} when is_list(logs) ->
        decoded_logs =
          if opts[:abi] do
            Enum.map(logs, &decode_log(&1, opts[:abi]))
          else
            logs
          end
          
        Enum.each(decoded_logs, &Storage.insert/1)
        {:ok, length(decoded_logs)}
      
      {:ok, %Req.Response{body: %{"error" => error}}} ->
        {:error, error}
        
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  def decode_log(log, abi) do
    try do
      topics = log["topics"] || []
      
      # Parse the ABI if it's a string, or assume it's already parsed
      parsed_abi = if is_binary(abi), do: ABI.parse_specification(Jason.decode!(abi), include_events?: true), else: abi
      
      topic_data = Enum.map(topics, fn t -> 
        if is_nil(t), do: nil, else: t |> String.replace_leading("0x", "") |> Base.decode16!(case: :mixed) 
      end)
      
      # pad topics to length 4
      [t1, t2, t3, t4] = Enum.take(topic_data ++ [nil, nil, nil, nil], 4)
      
      data_bytes = (log["data"] || "0x") |> String.replace_leading("0x", "") |> Base.decode16!(case: :mixed)
      
      case ABI.Event.find_and_decode(parsed_abi, t1, t2, t3, t4, data_bytes) do
        {_selector, decoded_values} ->
          formatted_values = Enum.into(decoded_values, %{}, fn {name, _type, _indexed, value} -> {name, value} end)
          Map.put(log, "decoded", formatted_values)
        {:error, _} ->
          log
      end
    rescue
      e -> 
        require Logger
        Logger.error("[Lux.Web3.EventMonitor] Failed to decode log: #{inspect(e)}")
        log
    end
  end

  @doc """
  Queries stored events.
  """
  def query_events(opts \\ []) do
    Storage.query(opts)
  end
  
  @doc """
  Clears stored events.
  """
  def clear_events do
    Storage.clear()
  end
end
