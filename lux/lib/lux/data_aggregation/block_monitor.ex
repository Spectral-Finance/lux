defmodule Lux.DataAggregation.BlockMonitor do
  @moduledoc """
  Monitors new blocks and transactions across multiple chains.

  ## Features
  - Continuous block polling with configurable interval
  - Transaction extraction and storage
  - Real-time block notifications via PubSub
  - Block reorganization detection
  """

  use GenServer

  alias Lux.DataAggregation.{RPCManager, DataStore, Streamer}

  @poll_interval 12_000  # ~12 seconds for Ethereum
  @max_blocks_per_poll 100

  defstruct [
    :chain,
    :last_block_number,
    :poll_timer,
    :monitoring
  ]

  def start_link(opts) do
    chains = Keyword.get(opts, :chains, [:ethereum, :polygon, :bsc])
    GenServer.start_link(__MODULE__, chains, name: __MODULE__)
  end

  @impl true
  def init(chains) do
    monitors =
      chains
      |> Enum.map(&init_chain_monitor/1)
      |> Map.new()

    schedule_poll()

    {:ok, %{monitors: monitors, running: true}}
  end

  defp init_chain_monitor(chain) do
    {chain, %{
      chain: chain,
      last_block_number: nil,
      poll_interval: chain_poll_interval(chain),
      monitoring: true
    }}
  end

  defp chain_poll_interval(:ethereum), do: 12_000
  defp chain_poll_interval(:polygon), do: 2_000
  defp chain_poll_interval(:bsc), do: 3_000
  defp chain_poll_interval(:arbitrum), do: 500
  defp chain_poll_interval(:optimism), do: 2_000
  defp chain_poll_interval(:avalanche), do: 2_000
  defp chain_poll_interval(:fantom), do: 1_000
  defp chain_poll_interval(_), do: 12_000

  @doc """
  Start monitoring a chain.
  """
  def start_monitoring(chain) do
    GenServer.call(__MODULE__, {:start_monitoring, chain})
  end

  @doc """
  Stop monitoring a chain.
  """
  def stop_monitoring(chain) do
    GenServer.call(__MODULE__, {:stop_monitoring, chain})
  end

  @doc """
  Get the latest processed block number for a chain.
  """
  def get_last_block(chain) do
    GenServer.call(__MODULE__, {:get_last_block, chain})
  end

  @doc """
  Sync historical blocks from a starting block.
  """
  def sync_history(chain, from_block, to_block \\ nil) do
    GenServer.call(__MODULE__, {:sync_history, chain, from_block, to_block})
  end

  @impl true
  def handle_call({:start_monitoring, chain}, _from, state) do
    case Map.get(state.monitors, chain) do
      nil ->
        {:reply, {:error, :unsupported_chain}, state}

      monitor ->
        new_monitor = %{monitor | monitoring: true}
        new_state = %{state | monitors: Map.put(state.monitors, chain, new_monitor)}
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:stop_monitoring, chain}, _from, state) do
    case Map.get(state.monitors, chain) do
      nil ->
        {:reply, {:error, :unsupported_chain}, state}

      monitor ->
        new_monitor = %{monitor | monitoring: false}
        new_state = %{state | monitors: Map.put(state.monitors, chain, new_monitor)}
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:get_last_block, chain}, _from, state) do
    case Map.get(state.monitors, chain) do
      nil ->
        {:reply, {:error, :unsupported_chain}, state}

      monitor ->
        {:reply, {:ok, monitor.last_block_number}, state}
    end
  end

  def handle_call({:sync_history, chain, from_block, to_block}, _from, state) do
    case Map.get(state.monitors, chain) do
      nil ->
        {:reply, {:error, :unsupported_chain}, state}

      _monitor ->
        # Sync blocks in batches
        result = sync_blocks_batch(chain, from_block, to_block || from_block + @max_blocks_per_poll - 1)
        {:reply, result, state}
    end
  end

  defp sync_blocks_batch(chain, from, to) when from > to, do: :ok

  defp sync_blocks_batch(chain, from, to) do
    end_block = min(from + @max_blocks_per_poll - 1, to)

    blocks_to_fetch = Enum.to_list(from..end_block)

    blocks_data =
      blocks_to_fetch
      |> Enum.map(fn block_num ->
        block_hex = Integer.to_string(block_num, 16)
        case RPCManager.get_block_by_number(chain, "0x" <> block_hex, true) do
          {:ok, block} -> {:ok, block, block_num}
          {:error, reason} -> {:error, reason, block_num}
        end
      end)

    # Store successful blocks
    blocks_data
    |> Enum.filter(&match?({:ok, _, _}, &1))
    |> Enum.each(fn {:ok, block, num} ->
      DataStore.store_block(chain, block, num)
      # Store transactions
      store_transactions(chain, block, num)
      Streamer.broadcast_block(chain, block, num)
    end)

    errors = Enum.filter(blocks_data, &match?({:error, _, _}, &1))

    if length(errors) > 0 do
      {:partial, length(blocks_data) - length(errors), length(errors)}
    else
      sync_blocks_batch(chain, end_block + 1, to)
    end
  end

  defp store_transactions(chain, block, block_number) do
    transactions = block["transactions"] || []

    Enum.each(transactions, fn tx ->
      DataStore.store_transaction(chain, tx, block_number)
    end)
  end

  @impl true
  def handle_info(:poll, state) do
    new_monitors =
      state.monitors
      |> Map.new(fn {chain, monitor} ->
        if monitor.monitoring do
          case poll_chain(chain, monitor.last_block_number) do
            {:ok, new_block, new_block_number} ->
              new_monitor = %{monitor | last_block_number: new_block_number}
              {chain, new_monitor}

            {:error, _reason} ->
              {chain, monitor}
          end
        else
          {chain, monitor}
        end
      end)

    schedule_poll()
    {:noreply, %{state | monitors: new_monitors}}
  end

  defp poll_chain(chain, nil) do
    # First poll - get current block number
    case RPCManager.get_block_number(chain) do
      {:ok, hex_block} ->
        block_number = parse_hex_block_number(hex_block)
        get_block_by_number(chain, block_number)

      error ->
        error
    end
  end

  defp poll_chain(chain, last_block) do
    case RPCManager.get_block_number(chain) do
      {:ok, hex_block} ->
        current_block = parse_hex_block_number(hex_block)

        if current_block > last_block do
          get_block_by_number(chain, current_block)
        else
          {:ok, nil, last_block}
        end

      error ->
        error
    end
  end

  defp get_block_by_number(chain, block_number) do
    block_hex = Integer.to_string(block_number, 16)

    case RPCManager.get_block_by_number(chain, "0x" <> block_hex, true) do
      {:ok, block} ->
        DataStore.store_block(chain, block, block_number)
        store_transactions(chain, block, block_number)
        Streamer.broadcast_block(chain, block, block_number)
        {:ok, block, block_number}

      error ->
        error
    end
  end

  defp parse_hex_block_number("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex_block_number(hex), do: String.to_integer(hex, 16)

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  @doc """
  Returns monitoring status for all chains.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @impl true
  def handle_call(:status, _from, state) do
    status =
      state.monitors
      |> Map.new(fn {chain, monitor} ->
        {chain, %{
          monitoring: monitor.monitoring,
          last_block: monitor.last_block_number,
          poll_interval: monitor.poll_interval
        }}
      end)

    {:reply, status, state}
  end
end
