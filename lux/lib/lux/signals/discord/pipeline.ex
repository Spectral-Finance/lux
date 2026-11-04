defmodule Lux.Signals.Discord.Pipeline do
  @moduledoc """
  Signal processing pipeline for Discord events in Lux.

  Coordinates raw payload ingestion, bidirectional signal conversion,
  schema validation, error containment, and subscriber agent dispatching.
  """

  require Logger

  alias Lux.Signals.Discord.Converter

  @doc """
  Processes a raw Discord event through conversion and validation.
  """
  @spec process_event(String.t() | atom(), map()) :: {:ok, Lux.Signal.t()} | {:error, term()}
  def process_event(event_type, raw_data) do
    case Converter.to_signal(event_type, raw_data) do
      {:ok, signal} ->
        Logger.info("[Lux.Signals.Discord.Pipeline] Ingested #{inspect(signal.schema_id)} signal: #{signal.id}")
        {:ok, signal}

      {:error, reason} ->
        Logger.error("[Lux.Signals.Discord.Pipeline] Failed to process event #{event_type}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Dispatches a signal to an agent or handling prism.
  """
  @spec dispatch(Lux.Signal.t(), module() | pid()) :: {:ok, term()} | {:error, term()}
  def dispatch(signal, target) when is_atom(target) do
    if function_exported?(target, :handle_signal, 1) do
      target.handle_signal(signal)
    else
      {:ok, %{dispatched: true, target: target, signal_id: signal.id}}
    end
  end

  def dispatch(signal, pid) when is_pid(pid) do
    send(pid, {:discord_signal, signal})
    {:ok, %{dispatched: true, pid: pid, signal_id: signal.id}}
  end
end
