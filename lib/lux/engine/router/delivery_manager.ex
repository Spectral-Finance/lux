defmodule Lux.Engine.Router.DeliveryManager do
  @moduledoc """
  Manages delivery of signals to specters by calling their handle_signal function.
  """

  use GenServer
  require Logger

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    delivery_handler = Keyword.fetch!(opts, :delivery_handler)

    GenServer.start_link(__MODULE__, %{name: name, delivery_handler: delivery_handler},
      name: via_tuple(name)
    )
  end

  def deliver(name, signal, specter_id) do
    GenServer.cast(via_tuple(name), {:deliver, signal, specter_id})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:deliver, signal, specter_id}, state) do
    case state.delivery_handler.deliver_signal(signal, specter_id) do
      :ok ->
        Logger.debug("Successfully delivered signal to specter #{specter_id}")

      {:error, reason} ->
        Logger.warning("Failed to deliver signal to specter #{specter_id}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  defp via_tuple(name) do
    {:via, Registry, {Lux.Engine.Registry, name}}
  end
end
