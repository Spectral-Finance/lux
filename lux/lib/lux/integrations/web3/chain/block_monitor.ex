defmodule Lux.Integrations.Web3.Chain.BlockMonitor do
  @moduledoc """
  GenServer for real-time block monitoring across multiple chains.

  Polls for new blocks and notifies subscribers of new blocks and transactions.
  """

  use GenServer

  alias Lux.Integrations.Web3.Chain.RpcClient

  defstruct [:chain, :rpc_url, :poll_interval_ms, :last_block, :subscribers, :plug]

  # Client API

  def start_link(opts) do
    name = opts[:name]
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def subscribe(pid, subscriber_pid) do
    GenServer.call(pid, {:subscribe, subscriber_pid})
  end

  def unsubscribe(pid, subscriber_pid) do
    GenServer.call(pid, {:unsubscribe, subscriber_pid})
  end

  def current_block(pid) do
    GenServer.call(pid, :current_block)
  end

  def status(pid) do
    GenServer.call(pid, :status)
  end

  # Server

  @impl true
  def init(opts) do
    state = %__MODULE__{
      chain: opts[:chain],
      rpc_url: opts[:rpc_url],
      poll_interval_ms: opts[:poll_interval_ms] || 12_000,
      last_block: nil,
      subscribers: MapSet.new(),
      plug: opts[:plug]
    }

    if opts[:auto_start] != false do
      send(self(), :poll)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  @impl true
  def handle_call({:unsubscribe, pid}, _from, state) do
    {:reply, :ok, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_call(:current_block, _from, state) do
    {:reply, state.last_block, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{
      chain: state.chain,
      last_block: state.last_block,
      subscribers: MapSet.size(state.subscribers),
      poll_interval_ms: state.poll_interval_ms
    }, state}
  end

  @impl true
  def handle_info(:poll, state) do
    opts = [rpc_url: state.rpc_url] ++ if(state.plug, do: [plug: state.plug], else: [])

    state = case RpcClient.call("eth_blockNumber", [], opts) do
      {:ok, hex} ->
        block_num = parse_hex(hex)
        if state.last_block != block_num do
          notify_subscribers(state.subscribers, {:new_block, state.chain, block_num})
          %{state | last_block: block_num}
        else
          state
        end

      {:error, _} ->
        state
    end

    Process.send_after(self(), :poll, state.poll_interval_ms)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  defp notify_subscribers(subscribers, message) do
    Enum.each(subscribers, &send(&1, message))
  end

  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(_), do: 0
end
