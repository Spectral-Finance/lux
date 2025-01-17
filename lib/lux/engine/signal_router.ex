defmodule Lux.Engine.SignalRouter do
  @moduledoc """
  Routes signals to specters based on their subscription patterns.
  Uses SubscriptionRegistry for pattern matching and storage.
  """

  use GenServer

  alias Lux.Engine.Subscription.Pattern

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  def register(router, specter_id, pattern) do
    GenServer.call(via_tuple(router), {:register, specter_id, pattern})
  end

  def unregister(router, specter_id) do
    GenServer.call(via_tuple(router), {:unregister, specter_id})
  end

  def route_signal(router, signal) do
    GenServer.call(via_tuple(router), {:route_signal, signal})
  end

  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    {:ok, %{name: name}}
  end

  def handle_call({:register, specter_id, pattern}, _from, state) do
    Lux.Engine.SubscriptionRegistry.register(state.name, specter_id, pattern)
    {:reply, :ok, state}
  end

  def handle_call({:unregister, specter_id}, _from, state) do
    Lux.Engine.SubscriptionRegistry.unregister(state.name, specter_id)
    {:reply, :ok, state}
  end

  def handle_call({:route_signal, signal}, _from, state) do
    matches = Lux.Engine.SubscriptionRegistry.find_matching_specters(state.name, signal)
    {:reply, matches, state}
  end

  defp via_tuple(name) do
    {:via, Registry, {name, "signal_router"}}
  end
end
