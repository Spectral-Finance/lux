defmodule Lux.Engine.Router.SignalRouter do
  @moduledoc """
  Routes signals to matching specters based on subscription patterns.
  """

  use GenServer
  require Logger

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  def route_signal(name, signal, delivery_handler) do
    GenServer.cast(via_tuple(name), {:route_signal, signal, delivery_handler})
  end

  @impl true
  def init(opts) do
    state = %{
      name: Keyword.fetch!(opts, :name),
      registry: Keyword.fetch!(opts, :registry)
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:route_signal, signal, delivery_handler}, state) do
    matching_specters = find_matching_specters(state.registry, signal)

    Enum.each(matching_specters, fn specter_id ->
      delivery_handler.deliver_signal(signal, specter_id)
    end)

    {:noreply, state}
  end

  defp find_matching_specters(registry, signal) do
    Lux.Engine.SubscriptionRegistry.find_matching_specters(registry, signal)
  end

  defp via_tuple(name) do
    {:via, Registry, {Lux.Engine.Registry, name}}
  end
end
