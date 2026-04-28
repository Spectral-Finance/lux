defmodule Lux.Integrations.MultiChainAggregator.BlockMonitor do
  @moduledoc """
  Real-time block and transaction monitor for a specific chain.
  Tracks new blocks, decodes transactions, and emits events.
  """

  use GenServer

  alias Lux.Integrations.MultiChainAggregator.{DataStore, Streamer}

  def start_link(chain, config, rpc_pid) do
    GenServer.start_link(__MODULE__, {chain, config, rpc_pid}, name: via(chain))
  end

  def init({chain, config, rpc_pid}) do
    schedule_poll(config.block_time)
    {:ok, %{chain: chain, config: config, rpc: rpc_pid, last_block: nil, block_count: 0}}
  end

  def handle_info(:poll_block, state) do
    case Lux.Integrations.MultiChainAggregator.get_latest_block(state.chain) do
      {:ok, block_num} when is_integer(block_num) ->
        if block_num != state.last_block do
          process_new_block(state.chain, block_num)
          schedule_poll(state.config.block_time)
          {:noreply, %{state | last_block: block_num, block_count: state.block_count + 1}}
        else
          schedule_poll(state.config.block_time)
          {:noreply, state}
        end

      {:error, _reason} ->
        schedule_poll(state.config.block_time * 2)
        {:noreply, state}
    end
  end

  defp process_new_block(chain, block_num) do
    block = Lux.Integrations.MultiChainAggregator.get_block(chain, block_num, true)
    DataStore.store_block(chain, block)
    Streamer.emit(chain, {:new_block, block})
  end

  defp schedule_poll(interval), do: Process.send_after(self(), :poll_block, interval)
  defp via(chain), do: {:via, Registry, {Lux.Registry, {:block_monitor, chain}}}
end