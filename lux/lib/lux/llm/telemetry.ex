defmodule Lux.LLM.Telemetry do
  @moduledoc """
  Cost tracking, token accounting, and performance telemetry for LLM providers.

  Tracks per-provider and per-model request volume, success/failure rates,
  cache hit rates, fallback invocations, token usage, estimated USD cost,
  and latency statistics in an ETS table (`:lux_llm_telemetry`).
  """

  alias Lux.LLM.ProviderRegistry

  @table :lux_llm_telemetry

  @type request_event :: %{
          optional(:status) => :ok | :error,
          optional(:latency_ms) => non_neg_integer(),
          optional(:prompt_tokens) => non_neg_integer(),
          optional(:completion_tokens) => non_neg_integer(),
          optional(:cost_usd) => float(),
          optional(:cache_hit) => boolean(),
          optional(:fallback) => boolean(),
          optional(:error) => term()
        }

  @doc """
  Ensures the telemetry ETS table exists.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
          :ok
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  @doc """
  Clears all recorded telemetry metrics.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc """
  Estimates token count for a string or message list (~4 characters per token heuristic).
  """
  @spec estimate_tokens(term()) :: non_neg_integer()
  def estimate_tokens(text) when is_binary(text) do
    max(1, div(String.length(text) + 3, 4))
  end

  def estimate_tokens(messages) when is_list(messages) do
    Enum.reduce(messages, 0, fn
      %{content: content}, acc when is_binary(content) -> acc + estimate_tokens(content)
      %{"content" => content}, acc when is_binary(content) -> acc + estimate_tokens(content)
      msg, acc when is_binary(msg) -> acc + estimate_tokens(msg)
      other, acc -> acc + estimate_tokens(inspect(other))
    end)
  end

  def estimate_tokens(nil), do: 0
  def estimate_tokens(other), do: estimate_tokens(inspect(other))

  @doc """
  Calculates the USD cost for a request given provider, model, prompt tokens,
  and completion tokens.
  """
  @spec calculate_cost(atom(), String.t(), non_neg_integer(), non_neg_integer()) :: float()
  def calculate_cost(provider_id, model_name, prompt_tokens, completion_tokens) do
    {input_rate, output_rate} =
      case ProviderRegistry.find_model(provider_id, model_name) do
        {:ok, info} ->
          {info.input_cost_per_1k, info.output_cost_per_1k}

        {:error, :not_found} ->
          {0.001, 0.002}
      end

    Float.round(
      prompt_tokens / 1000.0 * input_rate + completion_tokens / 1000.0 * output_rate,
      8
    )
  end

  @doc """
  Records a completed LLM request event and updates provider & model metrics.
  """
  @spec record_request(atom(), String.t(), request_event()) :: :ok
  def record_request(provider_id, model_name, event)
      when is_atom(provider_id) and is_binary(model_name) and is_map(event) do
    ensure_started()

    status = Map.get(event, :status, :ok)
    latency_ms = max(0, Map.get(event, :latency_ms, 0))
    prompt_tokens = max(0, Map.get(event, :prompt_tokens, 0))
    completion_tokens = max(0, Map.get(event, :completion_tokens, 0))
    cache_hit = Map.get(event, :cache_hit, false)
    fallback = Map.get(event, :fallback, false)

    cost_usd =
      case Map.get(event, :cost_usd) do
        cost when is_number(cost) ->
          cost * 1.0

        _ ->
          if cache_hit do
            0.0
          else
            calculate_cost(provider_id, model_name, prompt_tokens, completion_tokens)
          end
      end

    normalized_event = %{
      status: status,
      latency_ms: latency_ms,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      total_tokens: prompt_tokens + completion_tokens,
      cost_usd: cost_usd,
      cache_hit: cache_hit,
      fallback: fallback
    }

    update_bucket({:provider, provider_id}, normalized_event)
    update_bucket({:model, provider_id, model_name}, normalized_event)
    update_bucket(:global, normalized_event)
    :ok
  end

  @doc """
  Retrieves aggregated metrics across all providers and models.
  """
  @spec get_metrics() :: map()
  def get_metrics do
    ensure_started()
    entries = :ets.tab2list(@table)

    global =
      case List.keyfind(entries, :global, 0) do
        {:global, stats} -> finalize_stats(stats)
        nil -> finalize_stats(empty_bucket())
      end

    providers =
      for {{:provider, provider_id}, stats} <- entries, into: %{} do
        {provider_id, finalize_stats(stats)}
      end

    models =
      for {{:model, provider_id, model_name}, stats} <- entries, into: %{} do
        {{provider_id, model_name}, finalize_stats(stats)}
      end

    %{
      global: global,
      providers: providers,
      models: models
    }
  end

  @doc """
  Retrieves aggregated metrics for a single provider.
  """
  @spec get_provider_stats(atom()) :: map()
  def get_provider_stats(provider_id) when is_atom(provider_id) do
    ensure_started()

    case :ets.lookup(@table, {:provider, provider_id}) do
      [{_, stats}] -> finalize_stats(stats)
      [] -> finalize_stats(empty_bucket())
    end
  end

  @doc """
  Retrieves the observed average latency in milliseconds for a `{provider_id, model_name}` pair,
  or `nil` if no requests have been recorded.
  """
  @spec observed_latency_ms(atom(), String.t()) :: float() | nil
  def observed_latency_ms(provider_id, model_name) do
    ensure_started()

    case :ets.lookup(@table, {:model, provider_id, model_name}) do
      [{_, %{total_requests: count, total_latency_ms: total}}] when count > 0 ->
        total / count

      _ ->
        nil
    end
  end

  defp update_bucket(key, event) do
    current =
      case :ets.lookup(@table, key) do
        [{^key, bucket}] -> bucket
        [] -> empty_bucket()
      end

    total_requests = current.total_requests + 1

    successful_requests =
      if event.status == :ok,
        do: current.successful_requests + 1,
        else: current.successful_requests

    failed_requests =
      if event.status == :error,
        do: current.failed_requests + 1,
        else: current.failed_requests

    cache_hits = if event.cache_hit, do: current.cache_hits + 1, else: current.cache_hits
    fallbacks = if event.fallback, do: current.fallback_count + 1, else: current.fallback_count

    min_latency =
      case current.min_latency_ms do
        nil -> event.latency_ms
        existing -> min(existing, event.latency_ms)
      end

    max_latency = max(current.max_latency_ms, event.latency_ms)

    updated = %{
      total_requests: total_requests,
      successful_requests: successful_requests,
      failed_requests: failed_requests,
      cache_hits: cache_hits,
      fallback_count: fallbacks,
      prompt_tokens: current.prompt_tokens + event.prompt_tokens,
      completion_tokens: current.completion_tokens + event.completion_tokens,
      total_tokens: current.total_tokens + event.total_tokens,
      total_cost_usd: Float.round(current.total_cost_usd + event.cost_usd, 8),
      total_latency_ms: current.total_latency_ms + event.latency_ms,
      min_latency_ms: min_latency,
      max_latency_ms: max_latency
    }

    :ets.insert(@table, {key, updated})
  end

  defp empty_bucket do
    %{
      total_requests: 0,
      successful_requests: 0,
      failed_requests: 0,
      cache_hits: 0,
      fallback_count: 0,
      prompt_tokens: 0,
      completion_tokens: 0,
      total_tokens: 0,
      total_cost_usd: 0.0,
      total_latency_ms: 0,
      min_latency_ms: nil,
      max_latency_ms: 0
    }
  end

  defp finalize_stats(bucket) do
    avg_latency_ms =
      if bucket.total_requests > 0 do
        Float.round(bucket.total_latency_ms / bucket.total_requests, 2)
      else
        0.0
      end

    Map.put(bucket, :avg_latency_ms, avg_latency_ms)
  end
end
