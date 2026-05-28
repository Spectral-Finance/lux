defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal LLM provider interface with automatic model selection,
  intelligent fallback handling, cost tracking, and performance monitoring.

  ## Overview

  `Lux.LLM.Provider` acts as a smart router over all registered LLM backends
  (OpenAI, Anthropic, Together AI, Ollama, OpenRouter). It selects the best
  provider based on cost, latency, capability requirements, and falls back
  automatically when a provider fails.

  ## Configuration

      config :lux, Lux.LLM.Provider,
        providers: [
          %{module: Lux.LLM.OpenAI,      priority: 1, cost_per_1k: 0.030, tags: [:cloud, :tools]},
          %{module: Lux.LLM.Anthropic,   priority: 2, cost_per_1k: 0.015, tags: [:cloud, :tools]},
          %{module: Lux.LLM.TogetherAI,  priority: 3, cost_per_1k: 0.002, tags: [:cloud]},
          %{module: Lux.LLM.OpenRouter,  priority: 4, cost_per_1k: 0.005, tags: [:cloud, :tools]},
          %{module: Lux.LLM.Ollama,      priority: 5, cost_per_1k: 0.000, tags: [:local]}
        ],
        selection: :cost,          # :cost | :latency | :priority | :random
        fallback: true,            # retry on next provider on failure
        cache_ttl: 300,            # seconds; 0 to disable
        track_costs: true

  ## Usage

      # Let the router choose the best provider
      Lux.LLM.Provider.call("Summarise this PR", [], %{tags: [:tools]})

      # Force a specific provider
      Lux.LLM.Provider.call("Hello", [], %{provider: Lux.LLM.Ollama, model: "mistral"})

      # Read accumulated stats
      Lux.LLM.Provider.stats()
  """

  @behaviour Lux.LLM

  require Logger

  # ── ETS table name for cache + stats ────────────────────────────────────────
  @table :lux_llm_provider

  # ── Default provider registry ────────────────────────────────────────────────
  @default_providers [
    %{module: Lux.LLM.OpenAI,     priority: 1, cost_per_1k: 0.030, tags: [:cloud, :tools]},
    %{module: Lux.LLM.Anthropic,  priority: 2, cost_per_1k: 0.015, tags: [:cloud, :tools]},
    %{module: Lux.LLM.OpenRouter, priority: 3, cost_per_1k: 0.005, tags: [:cloud, :tools]},
    %{module: Lux.LLM.Ollama,     priority: 4, cost_per_1k: 0.000, tags: [:local]}
  ]

  # ── Public API ───────────────────────────────────────────────────────────────

  @impl true
  def call(prompt, tools, config) when is_map(config) do
    ensure_table()
    cfg = load_config(config)

    case Map.get(config, :provider) do
      nil -> route_with_fallback(prompt, tools, cfg)
      mod -> mod.call(prompt, tools, Map.drop(config, [:provider]))
    end
  end

  @doc "Returns accumulated cost and call statistics per provider."
  @spec stats() :: map()
  def stats do
    ensure_table()

    :ets.tab2list(@table)
    |> Enum.filter(fn {k, _} -> match?({:stats, _}, k) end)
    |> Map.new(fn {{:stats, mod}, v} -> {mod, v} end)
  end

  @doc "Clears the response cache."
  @spec clear_cache() :: :ok
  def clear_cache do
    ensure_table()

    :ets.match_delete(@table, {{:cache, :_}, :_})
    :ok
  end

  # ── Selection & fallback ─────────────────────────────────────────────────────

  defp route_with_fallback(prompt, tools, %{providers: providers, fallback: fallback?} = cfg) do
    ordered = select_providers(providers, cfg)
    try_providers(prompt, tools, cfg, ordered, fallback?)
  end

  defp try_providers(_prompt, _tools, _cfg, [], _fallback?),
    do: {:error, "All providers exhausted"}

  defp try_providers(prompt, tools, cfg, [provider | rest], fallback?) do
    cache_key = cache_key(prompt, provider.module)

    case get_cached(cache_key, cfg.cache_ttl) do
      {:hit, result} ->
        Logger.debug("[Provider] Cache hit for #{inspect(provider.module)}")
        result

      :miss ->
        t0 = System.monotonic_time(:millisecond)
        result = provider.module.call(prompt, tools, provider_config(provider, cfg))
        elapsed = System.monotonic_time(:millisecond) - t0

        case result do
          {:ok, _} = ok ->
            record_stats(provider.module, :ok, elapsed, estimated_tokens(prompt))
            maybe_cache(cache_key, ok, cfg.cache_ttl)
            ok

          {:error, reason} when fallback? ->
            Logger.warning("[Provider] #{inspect(provider.module)} failed: #{inspect(reason)}. Trying next.")
            record_stats(provider.module, :error, elapsed, 0)
            try_providers(prompt, tools, cfg, rest, fallback?)

          {:error, _} = err ->
            err
        end
    end
  end

  # ── Provider selection strategies ────────────────────────────────────────────

  defp select_providers(providers, %{selection: :cost, tags: tags}) do
    providers
    |> filter_by_tags(tags)
    |> Enum.sort_by(& &1.cost_per_1k)
  end

  defp select_providers(providers, %{selection: :latency, tags: tags}) do
    providers
    |> filter_by_tags(tags)
    |> Enum.sort_by(&avg_latency/1)
  end

  defp select_providers(providers, %{selection: :random, tags: tags}) do
    providers
    |> filter_by_tags(tags)
    |> Enum.shuffle()
  end

  defp select_providers(providers, %{tags: tags}) do
    providers
    |> filter_by_tags(tags)
    |> Enum.sort_by(& &1.priority)
  end

  defp filter_by_tags(providers, []), do: providers

  defp filter_by_tags(providers, tags) do
    Enum.filter(providers, fn p ->
      Enum.any?(tags, &(&1 in p.tags))
    end)
  end

  # ── Config helpers ────────────────────────────────────────────────────────────

  defp load_config(overrides) do
    defaults = Application.get_env(:lux, __MODULE__, [])

    %{
      providers: Keyword.get(defaults, :providers, @default_providers),
      selection: Keyword.get(defaults, :selection, :priority),
      fallback: Keyword.get(defaults, :fallback, true),
      cache_ttl: Keyword.get(defaults, :cache_ttl, 0),
      track_costs: Keyword.get(defaults, :track_costs, true),
      tags: Map.get(overrides, :tags, [])
    }
  end

  defp provider_config(provider, cfg) do
    base = Map.get(provider, :config, %{})
    Map.merge(base, %{track_costs: cfg.track_costs})
  end

  # ── Cache ─────────────────────────────────────────────────────────────────────

  defp cache_key(prompt, module), do: {:cache, :erlang.phash2({prompt, module})}

  defp get_cached(_key, 0), do: :miss
  defp get_cached(_key, nil), do: :miss

  defp get_cached(key, ttl) do
    case :ets.lookup(@table, key) do
      [{^key, {result, inserted_at}}] ->
        if System.monotonic_time(:second) - inserted_at < ttl do
          {:hit, result}
        else
          :ets.delete(@table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp maybe_cache(_key, _result, 0), do: :ok
  defp maybe_cache(_key, _result, nil), do: :ok

  defp maybe_cache(key, result, _ttl) do
    :ets.insert(@table, {key, {result, System.monotonic_time(:second)}})
    :ok
  end

  # ── Stats ─────────────────────────────────────────────────────────────────────

  defp record_stats(module, status, latency_ms, tokens) do
    key = {:stats, module}

    current =
      case :ets.lookup(@table, key) do
        [{^key, v}] -> v
        [] -> %{calls: 0, errors: 0, total_latency_ms: 0, total_tokens: 0, total_cost: 0.0}
      end

    provider_def = Enum.find(@default_providers, &(&1.module == module)) || %{cost_per_1k: 0.0}
    cost = tokens / 1000 * provider_def.cost_per_1k

    updated =
      current
      |> Map.update!(:calls, &(&1 + 1))
      |> Map.update!(:errors, &(if status == :error, do: &1 + 1, else: &1))
      |> Map.update!(:total_latency_ms, &(&1 + latency_ms))
      |> Map.update!(:total_tokens, &(&1 + tokens))
      |> Map.update!(:total_cost, &(&1 + cost))
      |> Map.put(:avg_latency_ms, div(current.total_latency_ms + latency_ms, current.calls + 1))

    :ets.insert(@table, {key, updated})
  end

  defp avg_latency(%{module: module}) do
    key = {:stats, module}

    case :ets.lookup(@table, key) do
      [{^key, %{avg_latency_ms: ms}}] -> ms
      _ -> 999_999
    end
  end

  defp estimated_tokens(prompt) when is_binary(prompt) do
    div(String.length(prompt), 4)
  end

  defp estimated_tokens(_), do: 0

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> @table
    end
  end
end
