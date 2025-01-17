defmodule Lux.Specter.Runner do
  @moduledoc """
  GenServer implementation for running individual Specter processes.
  Handles the specter's lifecycle, scheduled tasks, and reflection process.
  """

  use GenServer

  # Client API

  def start_link(%Lux.Specter{} = specter) do
    GenServer.start_link(__MODULE__, specter)
  end

  def get_specter(pid) do
    GenServer.call(pid, :get_specter)
  end

  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def schedule_beam(pid, beam_module, cron_expression, opts \\ []) do
    GenServer.call(pid, {:schedule_beam, beam_module, cron_expression, opts})
  end

  def unschedule_beam(pid, beam_module) do
    GenServer.call(pid, {:unschedule_beam, beam_module})
  end

  def handle_signal(pid, signal) do
    GenServer.cast(pid, {:handle_signal, signal})
  end

  def trigger_learning(pid) do
    GenServer.cast(pid, :learn)
  end

  # Server Callbacks

  @impl true
  def init(%Lux.Specter{} = specter) do
    # Schedule initial reflection cycle
    schedule_reflection(specter.reflection_interval)
    # Schedule beam check
    schedule_beam_check()
    # Schedule periodic learning
    schedule_learning()

    {:ok, %{specter: specter, context: %{}}}
  end

  @impl true
  def handle_call(:get_specter, _from, %{specter: specter} = state) do
    {:reply, {:ok, specter, self()}, state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_call(
        {:schedule_beam, beam_module, cron_expression, opts},
        _from,
        %{specter: specter} = state
      ) do
    case Lux.Specter.schedule_beam(specter, beam_module, cron_expression, opts) do
      {:ok, updated_specter} ->
        {:reply, :ok, %{state | specter: updated_specter}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:unschedule_beam, beam_module}, _from, %{specter: specter} = state) do
    case Lux.Specter.unschedule_beam(specter, beam_module) do
      {:ok, updated_specter} ->
        {:reply, :ok, %{state | specter: updated_specter}}
    end
  end

  @impl true
  def handle_cast({:handle_signal, signal}, %{specter: specter} = state) do
    case Lux.Specter.handle_signal(specter, signal) do
      {:ok, actions} ->
        execute_actions(actions, state)
        {:noreply, state}

      :ignore ->
        {:noreply, state}

      {:error, _reason} ->
        # Log error but don't crash
        {:noreply, state}
    end
  end

  def handle_cast(:learn, %{specter: specter} = state) do
    # Update reflection through learning
    updated_reflection = Lux.Reflection.learn(specter.reflection)
    updated_specter = %{specter | reflection: updated_reflection}

    {:noreply, %{state | specter: updated_specter}}
  end

  @impl true
  def handle_info(:reflect, %{specter: specter} = state) do
    # Execute reflection cycle
    case Lux.Specter.reflect(specter, state.context) do
      {:ok, results, updated_specter} ->
        # Update context with results
        new_context = update_context(state.context, results)
        # Schedule next reflection cycle
        schedule_reflection(updated_specter.reflection_interval)
        {:noreply, %{state | specter: updated_specter, context: new_context}}

      {:error, _reason, updated_specter} ->
        # Log error but don't crash
        schedule_reflection(updated_specter.reflection_interval)
        {:noreply, %{state | specter: updated_specter}}
    end
  end

  def handle_info(:check_beams, %{specter: specter} = state) do
    # Get and execute due beams
    due_beams = Lux.Specter.get_due_beams(specter)

    Enum.each(due_beams, fn {beam_module, _cron, opts} ->
      Task.start(fn ->
        beam_module.run(opts[:input] || %{}, %{specter: specter})
      end)
    end)

    # Schedule next check
    schedule_beam_check()
    {:noreply, state}
  end

  def handle_info(:trigger_learning, state) do
    # Trigger learning process
    handle_cast(:learn, state)
    # Schedule next learning cycle
    schedule_learning()
    {:noreply, state}
  end

  # Private Helpers

  defp schedule_reflection(interval) do
    Process.send_after(self(), :reflect, interval)
  end

  defp schedule_beam_check do
    # Check beams every minute
    Process.send_after(self(), :check_beams, 60_000)
  end

  defp schedule_learning do
    # Trigger learning every hour
    Process.send_after(self(), :trigger_learning, 60 * 60 * 1000)
  end

  defp update_context(context, results) do
    Map.merge(context, %{
      last_reflection_results: results,
      last_reflection_time: DateTime.utc_now()
    })
  end

  defp execute_actions(actions, state) do
    Enum.each(actions, fn {module, params} ->
      Task.start(fn ->
        module.run(params, %{specter: state.specter})
      end)
    end)
  end
end
