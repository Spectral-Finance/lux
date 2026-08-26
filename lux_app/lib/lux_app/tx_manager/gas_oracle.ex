defmodule LuxApp.TxManager.GasOracle do
  use GenServer
  
  @moduledoc """
  Gas price prediction system and base fee cache connected to RPC adapter with periodic polling.
  """

  @rpc_adapter Application.compile_env(:lux_app, :rpc_adapter, LuxApp.TxManager.RealRPC)
  @poll_interval 15_000 # 15 seconds block interval

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_current_base_fee do
    GenServer.call(__MODULE__, :get_base_fee)
  end

  def force_poll do
    GenServer.call(__MODULE__, :poll_now)
  end

  def set_mock_base_fee(fee) do
    GenServer.cast(__MODULE__, {:set_base_fee, fee})
  end

  def update_with_ema(new_block_base_fee) do
    GenServer.cast(__MODULE__, {:update_ema, new_block_base_fee})
  end

  @impl true
  def init(_opts) do
    initial_fee = 
      case @rpc_adapter.get_base_fee() do
        {:ok, fee} -> fee
        _ -> 30_000_000_000
      end

    schedule_poll()
    {:ok, %{base_fee: initial_fee, history: [initial_fee]}}
  end

  @impl true
  def handle_call(:get_base_fee, _from, state) do
    {:reply, state.base_fee, state}
  end

  @impl true
  def handle_call(:poll_now, _from, state) do
    new_state = fetch_and_update_fee(state)
    {:reply, new_state.base_fee, new_state}
  end

  @impl true
  def handle_cast({:set_base_fee, fee}, state) do
    {:noreply, %{state | base_fee: fee}}
  end

  @impl true
  def handle_cast({:update_ema, new_fee}, state) do
    ema_fee = trunc((new_fee * 0.3) + (state.base_fee * 0.7))
    {:noreply, %{state | base_fee: ema_fee, history: [new_fee | Enum.take(state.history, 9)]}}
  end

  @impl true
  def handle_info(:poll_base_fee, state) do
    new_state = fetch_and_update_fee(state)
    schedule_poll()
    {:noreply, new_state}
  end

  defp fetch_and_update_fee(state) do
    case @rpc_adapter.get_base_fee() do
      {:ok, new_fee} ->
        ema_fee = trunc((new_fee * 0.3) + (state.base_fee * 0.7))
        %{state | base_fee: ema_fee, history: [new_fee | Enum.take(state.history, 9)]}
      _ ->
        state
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll_base_fee, @poll_interval)
  end
end
