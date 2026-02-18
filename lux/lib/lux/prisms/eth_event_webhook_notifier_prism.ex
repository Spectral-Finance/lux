defmodule Lux.Prisms.EthEventWebhookNotifierPrism do
  use GenServer

  @moduledoc """
  A GenServer-backed Prism for managing event-specific webhook notifications.
  """

  # Client API

  def start_link(initial_state \\ %{}) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  def notify_event(contract_address, event_name, data) do
    GenServer.call(__MODULE__, {:notify, contract_address, event_name, data})
  end

  # Server callbacks

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_call({:notify, contract_address, event_name, data}, _from, state) do
    # Logic to send webhook notification
    IO.puts("Notifying event for contract #{contract_address} and event #{event_name}: #{inspect(data)}")
    {:reply, :ok, state}
  end
end