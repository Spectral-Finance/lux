defmodule Lux.LLM.Monitoring do
  @moduledoc """
  Cost and performance monitoring for LLM calls.

  Tracks:
    - Cost per provider/model
    - Response latency
    - Token usage
    - Error rates
    - Provider availability

  Uses ETS tables for lightweight, in-memory tracking. Data is aggregated
  per session and can be reset or exported.

  ## Usage

      # Track a call
      Lux.LLM.Monitoring.track(:openai, "gpt-4", :success, %{
        latency_ms: 1200,
        input_tokens: 150,
        output_tokens: 50,
        cost: 0.0005
      })

      # Get stats
      Lux.LLM.Monitoring.stats()
      Lux.LLM.Monitoring.stats(:openai)
  """

  @table_name :lux_llm_monitoring

  @doc """
  Start the monitoring ETS table.

  Called during application startup.
  """
  @spec start_link(keyword()) :: {:ok, :ets.tid()}
  def start_link(_opts \\ []) do
    table = :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    :ets.insert(@table_name, {:total_calls, 0})
    :ets.insert(@table_name, {:successful_calls, 0})
    :ets.insert(@table_name, {:failed_calls, 0})
    :ets.insert(@table_name, {:total_cost, 0.0})
    :ets.insert(@table_name, {:total_input_tokens, 0})
    :ets.insert(@table_name, {:total_output_tokens, 0})
    :ets.insert(@table_name, {:total_latency_ms, 0})
    {:ok, table}
  end

  @doc """
  Track an LLM call result.

  ## Parameters

    - `provider` - Provider name or module (e.g., `:openai`, `Lux.LLM.OpenAI`)
    - `model` - Model name (e.g., `"gpt-4"`, `"claude-3-opus"`)
    - `status` - `:success` or `:error`
    - `metadata` - Map with optional keys: `latency_ms`, `input_tokens`, `output_tokens`, `cost`, `error`
  """
  @spec track(atom() | module(), String.t(), :success | :error, map()) :: :ok
  def track(provider, model, status, metadata \\ %{}) do
    provider_name = normalize_provider(provider)

    # Update global counters
    :ets.update_counter(@table_name, :total_calls, 1)

    case status do
      :success ->
        :ets.update_counter(@table_name, :successful_calls, 1)

      :error ->
        :ets.update_counter(@table_name, :failed_calls, 1)
    end

    # Update cost
    if cost = Map.get(metadata, :cost, 0.0) do
      update_float(:total_cost, cost)
    end

    # Update tokens
    Enum.each([:input_tokens, :output_tokens], fn key ->
      if value = Map.get(metadata, key, 0) do
        :ets.update_counter(@table_name, :"total_#{key}", value)
      end
    end)

    # Update latency
    if latency = Map.get(metadata, :latency_ms, 0) do
      :ets.update_counter(@table_name, :total_latency_ms, latency)
    end

    # Track per-provider stats
    provider_key = {:provider, provider_name}
    update_provider_counter(provider_key, :total_calls, 1)

    case status do
      :success -> update_provider_counter(provider_key, :successful_calls, 1)
      :error -> update_provider_counter(provider_key, :failed_calls, 1)
    end

    # Track per-model stats
    model_key = {:model, provider_name, model}
    update_model_counter(model_key, :total_calls, 1)

    # Record detailed event for recent history (keep last 100)
    event = %{
      timestamp: DateTime.utc_now(),
      provider: provider_name,
      model: model,
      status: status,
      latency_ms: Map.get(metadata, :latency_ms, nil),
      input_tokens: Map.get(metadata, :input_tokens, nil),
      output_tokens: Map.get(metadata, :output_tokens, nil),
      cost: Map.get(metadata, :cost, nil),
      error: Map.get(metadata, :error, nil)
    }

    events_key = :recent_events
    events = :ets.lookup(@table_name, events_key)

    updated_events =
      case events do
        [{^events_key, list}] when is_list(list) ->
          [event | list] |> Enum.take(100)

        _ ->
          [event]
      end

    :ets.insert(@table_name, {events_key, updated_events})

    :ok
  end

  @doc """
  Get aggregated statistics.

  Optionally filter by provider name.

  Returns a map with:
    - `:total_calls` - Total number of tracked calls
    - `:successful_calls` - Number of successful calls
    - `:failed_calls` - Number of failed calls
    - `:success_rate` - Percentage of successful calls
    - `:total_cost` - Total cost across all calls
    - `:total_input_tokens` - Total input tokens
    - `:total_output_tokens` - Total output tokens
    - `:average_latency_ms` - Average response latency
    - `:recent_events` - Last 100 events
  """
  @spec stats(atom() | nil) :: map()
  def stats(provider \\ nil)

  def stats(nil) do
    {total, success, failed, cost, in_tokens, out_tokens, latency} = get_global_counters()

    %{
      total_calls: total,
      successful_calls: success,
      failed_calls: failed,
      success_rate: if(total > 0, do: Float.round(success / total * 100, 1), else: 100.0),
      total_cost: Float.round(cost, 6),
      total_input_tokens: in_tokens,
      total_output_tokens: out_tokens,
      average_latency_ms: if(total > 0, do: round(latency / total), else: 0),
      recent_events: get_recent_events()
    }
  end

  def stats(provider) do
    provider_name = normalize_provider(provider)
    provider_key = {:provider, provider_name}

    case :ets.lookup(@table_name, provider_key) do
      [{^provider_key, counters}] ->
        total = Map.get(counters, :total_calls, 0)
        success = Map.get(counters, :successful_calls, 0)

        %{
          provider: provider_name,
          total_calls: total,
          successful_calls: success,
          failed_calls: Map.get(counters, :failed_calls, 0),
          success_rate: if(total > 0, do: Float.round(success / total * 100, 1), else: 100.0),
          recent_events:
            get_recent_events()
            |> Enum.filter(fn e -> e.provider == provider_name end)
            |> Enum.take(20)
        }

      [] ->
        %{provider: provider_name, total_calls: 0, successful_calls: 0, failed_calls: 0, success_rate: 100.0, recent_events: []}
    end
  end

  @doc """
  Reset all monitoring data.
  """
  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@table_name)
    :ets.insert(@table_name, {:total_calls, 0})
    :ets.insert(@table_name, {:successful_calls, 0})
    :ets.insert(@table_name, {:failed_calls, 0})
    :ets.insert(@table_name, {:total_cost, 0.0})
    :ets.insert(@table_name, {:total_input_tokens, 0})
    :ets.insert(@table_name, {:total_output_tokens, 0})
    :ets.insert(@table_name, {:total_latency_ms, 0})
    :ok
  end

  # Private

  defp normalize_provider(provider) when is_atom(provider) do
    provider
    |> Module.split()
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end

  defp normalize_provider(provider) when is_binary(provider) do
    provider |> String.downcase() |> String.to_atom()
  end

  defp normalize_provider(provider) when is_atom(provider) do
    provider
  end

  defp get_global_counters do
    total = get_counter(:total_calls, 0)
    success = get_counter(:successful_calls, 0)
    failed = get_counter(:failed_calls, 0)
    cost = get_float(:total_cost, 0.0)
    in_tokens = get_counter(:total_input_tokens, 0)
    out_tokens = get_counter(:total_output_tokens, 0)
    latency = get_counter(:total_latency_ms, 0)

    {total, success, failed, cost, in_tokens, out_tokens, latency}
  end

  defp get_recent_events do
    case :ets.lookup(@table_name, :recent_events) do
      [{:recent_events, events}] -> events
      _ -> []
    end
  end

  defp get_counter(key, default) do
    case :ets.lookup(@table_name, key) do
      [{^key, value}] -> value
      _ -> default
    end
  end

  defp get_float(key, default) do
    case :ets.lookup(@table_name, key) do
      [{^key, value}] -> value
      _ -> default
    end
  end

  defp update_float(key, amount) do
    case :ets.lookup(@table_name, key) do
      [{^key, current}] ->
        :ets.insert(@table_name, {key, current + amount})

      _ ->
        :ets.insert(@table_name, {key, amount})
    end
  end

  defp update_provider_counter(provider_key, metric, delta) do
    case :ets.lookup(@table_name, provider_key) do
      [{^provider_key, counters}] ->
        updated = Map.update(counters, metric, delta, &(&1 + delta))
        :ets.insert(@table_name, {provider_key, updated})

      _ ->
        :ets.insert(@table_name, {provider_key, %{metric => delta}})
    end
  end

  defp update_model_counter(model_key, metric, delta) do
    case :ets.lookup(@table_name, model_key) do
      [{^model_key, counters}] ->
        updated = Map.update(counters, metric, delta, &(&1 + delta))
        :ets.insert(@table_name, {model_key, updated})

      _ ->
        :ets.insert(@table_name, {model_key, %{metric => delta}})
    end
  end
end
