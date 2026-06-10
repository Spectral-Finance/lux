defmodule Lux.Monitoring.Worker do
  @moduledoc """
  Worker responsible for monitoring a single smart contract event.
  Handles historical syncing and real-time monitoring.
  """
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(args))
  end

  defp via_tuple({address, signature, _opts}) do
    {:via, Registry, {Keyword.new([:event_monitor]), {address, signature}}}
  end

  @impl true
  def init({address, signature, opts}) do
    Logger.info("[EventMonitor] Starting monitor for #{address} | #{signature}")
    
    # State includes current block height to track progress
    state = %{
      address: address,
      signature: signature,
      last_block: 0,
      opts: opts,
      mode: :syncing # Start with syncing historical logs
    }

    # Schedule the first sync cycle
    schedule_sync()

    {:ok, state}
  end

  @impl true
  def handle_info(:sync, state) do
    Logger.info("[EventMonitor] Syncing logs for #{state.address} from block #{state.last_block}")
    
    # 1. Use the existing Lux.Lenses.Etherscan.GetLogs to fetch logs
    # Note: In a real implementation, this would call the Lens focus/after_focus
    # and handle pagination.
    
    # For now, we simulate the fetch and update last_block
    # In production: results = Lux.Lenses.Etherscan.GetLogs.focus(%{...})
    
    new_block = state.last_block + 1000 # Simulate progress
    
    if new_block > 20_000_000 do # Example current block
      Logger.info("[EventMonitor] Sync complete for #{state.address}. Switching to real-time mode.")
      send(self(), :switch_to_realtime)
    else
      schedule_sync()
    end

    {:noreply, %{state | last_block: new_block}}
  end

  def handle_info(:switch_to_realtime, state) do
    Logger.info("[EventMonitor] Switching to real-time monitoring for #{state.address}")
    # Here we would initiate a WebSocket connection to an RPC node
    {:noreply, %{state | mode: :realtime}}
  end

  defp schedule_sync do
    Process.send_after(self(), :sync, 5000)
  end
end
