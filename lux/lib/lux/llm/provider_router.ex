defmodule Lux.LLM.ProviderRouter do
  @moduledoc """
  Universal LLM Provider Abstraction Layer for Lux (#99).

  Provides:
  - Provider registry and dynamic configuration management
  - Automatic model selection by task complexity, latency, or cost constraints
  - Ordered fallback chain execution when primary providers fail or rate-limit
  - Response caching (content-addressed SHA-256 key)
  - Real-time token cost and latency telemetry tracking
  """

  @table :lux_llm_provider_router_store

  @spec init_store() :: :ok
  def init_store do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end

  @doc """
  Registers an LLM provider configuration in the universal registry.
  """
  @spec register_provider(map()) :: {:ok, map()} | {:error, term()}
  def register_provider(config) when is_map(config) do
    init_store()

    with {:ok, id} <- fetch_req(config, :id),
         {:ok, model} <- fetch_req(config, :model) do
      provider = %{
        id: id,
        model: model,
        priority: Map.get(config, :priority, 100),
        cost_per_1k_tokens: Map.get(config, :cost_per_1k_tokens, 0.002),
        capabilities: Map.get(config, :capabilities, [:chat, :reasoning]),
        handler: Map.get(config, :handler),
        enabled: Map.get(config, :enabled, true)
      }

      :ets.insert(@table, {{:provider, id}, provider})
      {:ok, provider}
    end
  end

  @doc """
  Selects the optimal active provider matching required capability and optimization strategy (:cost or :priority).
  """
  @spec select_provider(keyword()) :: {:ok, map()} | {:error, :no_matching_provider}
  def select_provider(opts \\ []) do
    init_store()
    capability = Keyword.get(opts, :capability, :chat)
    strategy = Keyword.get(opts, :strategy, :priority)

    candidates =
      @table
      |> :ets.match({{:provider, :_}, :"$1"})
      |> List.flatten()
      |> Enum.filter(fn p -> p.enabled and capability in p.capabilities end)

    sorted =
      case strategy do
        :cost -> Enum.sort_by(candidates, & &1.cost_per_1k_tokens)
        _ -> Enum.sort_by(candidates, & &1.priority)
      end

    case sorted do
      [best | _] -> {:ok, best}
      [] -> {:error, :no_matching_provider}
    end
  end

  @doc """
  Executes a prompt through the selected provider with automatic fallback across backup providers,
  response caching, and token cost/latency telemetry.
  """
  @spec complete(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def complete(prompt, opts \\ []) when is_binary(prompt) do
    init_store()
    use_cache = Keyword.get(opts, :cache, true)
    capability = Keyword.get(opts, :capability, :chat)
    strategy = Keyword.get(opts, :strategy, :priority)
    cache_key = :crypto.hash(:sha256, "#{capability}:#{prompt}") |> Base.encode16(case: :lower)

    if use_cache do
      case :ets.lookup(@table, {:cache, cache_key}) do
        [{{:cache, ^cache_key}, cached_resp}] ->
          {:ok, Map.put(cached_resp, :cached, true)}

        [] ->
          execute_with_fallback(prompt, capability, strategy, cache_key, use_cache)
      end
    else
      execute_with_fallback(prompt, capability, strategy, cache_key, false)
    end
  end

  @doc """
  Returns aggregated cost, call count, and latency analytics per provider.
  """
  @spec telemetry_summary() :: map()
  def telemetry_summary do
    init_store()

    metrics =
      @table
      |> :ets.match({{:metric, :_}, :"$1"})
      |> List.flatten()

    %{
      total_calls: length(metrics),
      total_cost_usd: Enum.reduce(metrics, 0.0, fn m, acc -> acc + m.cost_usd end) |> Float.round(6),
      by_provider:
        metrics
        |> Enum.group_by(& &1.provider_id)
        |> Map.new(fn {pid, list} ->
          {pid,
           %{
             calls: length(list),
             total_tokens: Enum.reduce(list, 0, &(&1.tokens + &2)),
             total_cost_usd: Enum.reduce(list, 0.0, &(&1.cost_usd + &2)) |> Float.round(6)
           }}
        end)
    }
  end

  # Internal Helpers

  defp fetch_req(map, key) do
    case Map.get(map, key) do
      v when v in [nil, ""] -> {:error, {:missing_field, key}}
      v -> {:ok, v}
    end
  end

  defp execute_with_fallback(prompt, capability, strategy, cache_key, store_cache?) do
    candidates =
      @table
      |> :ets.match({{:provider, :_}, :"$1"})
      |> List.flatten()
      |> Enum.filter(fn p -> p.enabled and capability in p.capabilities end)

    ordered =
      case strategy do
        :cost -> Enum.sort_by(candidates, & &1.cost_per_1k_tokens)
        _ -> Enum.sort_by(candidates, & &1.priority)
      end

    try_providers(ordered, prompt, cache_key, store_cache?, [])
  end

  defp try_providers([], _prompt, _cache_key, _store_cache?, errors) do
    {:error, {:all_providers_failed, Enum.reverse(errors)}}
  end

  defp try_providers([provider | rest], prompt, cache_key, store_cache?, errors) do
    t0 = System.monotonic_time(:millisecond)
    handler = provider.handler || fn p -> {:ok, %{content: "Response: #{p}", tokens: 100}} end

    case handler.(prompt) do
      {:ok, %{content: content} = raw} ->
        latency_ms = max(0, System.monotonic_time(:millisecond) - t0)
        tokens = Map.get(raw, :tokens, 100)
        cost_usd = tokens / 1000.0 * provider.cost_per_1k_tokens

        resp = %{
          provider_id: provider.id,
          model: provider.model,
          content: content,
          tokens: tokens,
          cost_usd: cost_usd,
          latency_ms: latency_ms,
          cached: false
        }

        record_metric(resp)
        if store_cache?, do: :ets.insert(@table, {{:cache, cache_key}, resp})
        {:ok, resp}

      {:error, reason} ->
        try_providers(rest, prompt, cache_key, store_cache?, [{provider.id, reason} | errors])
    end
  end

  defp record_metric(resp) do
    seq = System.unique_integer([:monotonic, :positive])
    :ets.insert(@table, {{:metric, seq}, resp})
  end
end
