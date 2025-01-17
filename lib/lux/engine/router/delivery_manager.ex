defmodule Lux.Engine.Router.DeliveryManager do
  @moduledoc """
  Manages delivery of signals to specters with retry logic and timeouts.
  """

  use GenServer
  require Logger

  @retry_interval 5_000
  @max_retries 3
  @delivery_timeout 30_000

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  def deliver(name, signal, specter_id) do
    GenServer.cast(via_tuple(name), {:deliver, signal, specter_id})
  end

  @impl true
  def init(opts) do
    state = %{
      name: Keyword.fetch!(opts, :name),
      delivery_handler: Keyword.fetch!(opts, :delivery_handler),
      pending_deliveries: %{},
      retry_counts: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:deliver, signal, specter_id}, state) do
    delivery_ref = make_ref()
    start_time = System.monotonic_time(:millisecond)

    case state.delivery_handler.deliver_signal(signal, specter_id) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        Logger.warning("Failed to deliver signal to specter #{specter_id}: #{inspect(reason)}")
        schedule_retry(delivery_ref, signal, specter_id)

        new_state =
          state
          |> store_pending_delivery(delivery_ref, signal, specter_id, start_time)
          |> increment_retry_count(delivery_ref)

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:retry_delivery, delivery_ref}, state) do
    case Map.get(state.pending_deliveries, delivery_ref) do
      nil ->
        {:noreply, state}

      %{signal: signal, specter_id: specter_id, retry_count: retry_count} ->
        if retry_count >= @max_retries do
          Logger.error("Max retries exceeded for delivery to specter #{specter_id}")

          new_state =
            state
            |> remove_pending_delivery(delivery_ref)
            |> remove_retry_count(delivery_ref)

          {:noreply, new_state}
        else
          case state.delivery_handler.deliver_signal(signal, specter_id) do
            :ok ->
              new_state =
                state
                |> remove_pending_delivery(delivery_ref)
                |> remove_retry_count(delivery_ref)

              {:noreply, new_state}

            {:error, _reason} ->
              schedule_retry(delivery_ref, signal, specter_id)

              new_state =
                state
                |> increment_retry_count(delivery_ref)

              {:noreply, new_state}
          end
        end
    end
  end

  def handle_info({:delivery_timeout, delivery_ref}, state) do
    case Map.get(state.pending_deliveries, delivery_ref) do
      nil ->
        {:noreply, state}

      %{specter_id: specter_id} ->
        Logger.warning("Delivery to specter #{specter_id} timed out")

        new_state =
          state
          |> remove_pending_delivery(delivery_ref)
          |> remove_retry_count(delivery_ref)

        {:noreply, new_state}
    end
  end

  # Private helpers

  defp schedule_retry(delivery_ref, _signal, _specter_id) do
    Process.send_after(self(), {:retry_delivery, delivery_ref}, @retry_interval)
  end

  defp store_pending_delivery(state, ref, signal, specter_id, start_time) do
    delivery = %{
      signal: signal,
      specter_id: specter_id,
      start_time: start_time,
      retry_count: 0
    }

    Process.send_after(self(), {:delivery_timeout, ref}, @delivery_timeout)
    %{state | pending_deliveries: Map.put(state.pending_deliveries, ref, delivery)}
  end

  defp remove_pending_delivery(state, ref) do
    %{state | pending_deliveries: Map.delete(state.pending_deliveries, ref)}
  end

  defp increment_retry_count(state, ref) do
    retry_count = Map.get(state.retry_counts, ref, 0)
    %{state | retry_counts: Map.put(state.retry_counts, ref, retry_count + 1)}
  end

  defp remove_retry_count(state, ref) do
    %{state | retry_counts: Map.delete(state.retry_counts, ref)}
  end

  defp via_tuple(name) do
    {:via, Registry, {Lux.Engine.Registry, name}}
  end
end
