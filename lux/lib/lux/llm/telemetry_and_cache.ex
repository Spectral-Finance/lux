defmodule Lux.LLM.TelemetryAndCache do
  @moduledoc """
  Deterministic prompt/response caching and real-time cost & latency telemetry for Lux LLMs.
  """

  @cache_table :lux_llm_response_cache
  @metrics_table :lux_llm_telemetry_metrics
  @default_ttl_ms 300_000

  def ensure_started do
    if :ets.whereis(@cache_table) == :undefined do
      :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
    end

    if :ets.whereis(@metrics_table) == :undefined do
      :ets.new(@metrics_table, [:named_table, :public, :set, write_concurrency: true])
    end

    :ok
  end

  @doc """
  Computes a deterministic SHA-256 cache key for `{prompt, tools, model, options}`.
  """
  def cache_key(prompt, tools, model, opts) do
    relevant_opts = Map.take(opts, [:temperature, :max_tokens, :system, :messages])
    payload = :erlang.term_to_binary({prompt, tools, model, relevant_opts})
    :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
  end

  @doc """
  Fetches a non-expired cached response if available.
  """
  def get_cached(key) do
    ensure_started()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@cache_table, key) do
      [{^key, response, expires_at}] when expires_at > now ->
        cached_resp =
          case response do
            %Lux.LLM.Response{} = r -> %{r | cached: true}
            other -> other
          end

        {:hit, cached_resp}

      [{^key, _response, _expired}] ->
        :ets.delete(@cache_table, key)
        :miss

      [] ->
        :miss
    end
  end

  @doc """
  Stores a response in the ETS cache with a TTL in milliseconds.
  """
  def put_cached(key, response, ttl_ms \\ @default_ttl_ms) do
    ensure_started()
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@cache_table, {key, response, expires_at})
    :ok
  end

  @doc """
  Clears all cached responses and resets telemetry counters.
  """
  def reset_all do
    ensure_started()
    :ets.delete_all_objects(@cache_table)
    :ets.delete_all_objects(@metrics_table)
    :ok
  end

  @doc """
  Records a cache hit for a provider and model.
  """
  def record_cache_hit(provider_id, model) do
    ensure_started()
    key = {:stats, provider_id, model}

    case :ets.lookup(@metrics_table, key) do
      [{^key, stats}] ->
        :ets.insert(@metrics_table, {key, %{stats | cache_hits: stats.cache_hits + 1}})

      [] ->
        :ets.insert(
          @metrics_table,
          {key,
           %{
             provider_id: provider_id,
             model: model,
             total_calls: 0,
             successful_calls: 0,
             failed_calls: 0,
             cache_hits: 1,
             total_latency_ms: 0.0,
             total_cost_usd: 0.0
           }}
        )
    end

    :ok
  end

  @doc """
  Records telemetry and estimated USD token cost for a provider call.
  """
  def record_call(%{
        provider_id: provider_id,
        model: model,
        latency_ms: latency_ms,
        success: success,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        metadata: metadata
      }) do
    ensure_started()
    cost_usd = estimate_cost_usd(input_tokens, output_tokens, metadata || %{})
    key = {:stats, provider_id, model}

    current =
      case :ets.lookup(@metrics_table, key) do
        [{^key, stats}] ->
          stats

        [] ->
          %{
            provider_id: provider_id,
            model: model,
            total_calls: 0,
            successful_calls: 0,
            failed_calls: 0,
            cache_hits: 0,
            total_latency_ms: 0.0,
            total_cost_usd: 0.0
          }
      end

    updated = %{
      current
      | total_calls: current.total_calls + 1,
        successful_calls: current.successful_calls + if(success, do: 1, else: 0),
        failed_calls: current.failed_calls + if(success, do: 0, else: 1),
        total_latency_ms: current.total_latency_ms + latency_ms,
        total_cost_usd: Float.round(current.total_cost_usd + cost_usd, 8)
    }

    :ets.insert(@metrics_table, {key, updated})
    :ok
  end

  @doc """
  Estimates USD cost for a request given input/output token counts and model pricing metadata.
  """
  def estimate_cost_usd(input_tokens, output_tokens, metadata) do
    in_rate = Map.get(metadata, :input_cost_per_1k, 0.0)
    out_rate = Map.get(metadata, :output_cost_per_1k, 0.0)
    input_tokens / 1_000.0 * in_rate + output_tokens / 1_000.0 * out_rate
  end

  @doc """
  Returns aggregated telemetry metrics across all providers and models.
  """
  def get_metrics do
    ensure_started()

    @metrics_table
    |> :ets.tab2list()
    |> Enum.map(fn {_key, stats} ->
      avg_latency =
        if stats.total_calls > 0 do
          Float.round(stats.total_latency_ms / stats.total_calls, 2)
        else
          0.0
        end

      Map.put(stats, :avg_latency_ms, avg_latency)
    end)
  end
end
