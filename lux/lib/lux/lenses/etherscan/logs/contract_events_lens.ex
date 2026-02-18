defmodule Lux.Lenses.Etherscan.Logs.ContractEventsLens do
  @moduledoc """
  A GenServer-backed Lens for managing contract event subscriptions on Etherscan.
  """

  # Client API

  def start_link(initial_state \\ %{}) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  def subscribe_to_event(contract_address, event_name) do
    GenServer.call(__MODULE__, {:subscribe, contract_address, event_name})
  end

  def unsubscribe_from_event(contract_address, event_name) do
    GenServer.call(__MODULE__, {:unsubscribe, contract_address, event_name})
  end

  # Server callbacks

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_call({:subscribe, contract_address, event_name}, _from, state) do
    new_state = Map.put(state, {contract_address, event_name}, :subscribed)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:unsubscribe, contract_address, event_name}, _from, state) do
    new_state = Map.delete(state, {contract_address, event_name})
    {:reply, :ok, new_state}
  end
end