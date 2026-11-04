defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal LLM Provider Abstraction Layer for Lux (`Spectral-Finance/lux#99`).

  Provides:
  - Universal provider specification & registry (`register_provider/2`, `list_providers/0`, `get_provider/1`)
  - Automatic model & provider selection (`select_provider/1`) based on task complexity, budget, or latency
  - Intelligent multi-provider fallback execution (`call_with_fallback/3`)
  - Deterministic ETS response caching & optimization (`clear_cache/0`)
  - Cost estimation & real-time performance telemetry (`get_metrics/0`, `reset_metrics/0`)

  ## Examples

      iex> {:ok, spec} = Lux.LLM.Provider.select_provider(%{strategy: :cost_optimized})
      iex> spec.id
      :together_ai

      iex> Lux.LLM.Provider.call_with_fallback("Summarize portfolio risk", [], %{
      ...>   strategy: :balanced,
      ...>   cache: true
      ...> })
  """

  require Logger

  @metrics_table :lux_llm_provider_metrics
  @cache_table :lux_llm_provider_cache
  @registry_table :lux_llm_provider_registry

  defmodule Spec do
    @moduledoc """
    Metadata and cost/performance profile for a registered LLM provider.
    """
    @type t :: %__MODULE__{
            id: atom(),
            module: module(),
            default_model: String.t(),
            models: [String.t()],
            cost_per_1k_input: float(),
            cost_per_1k_output: float(),
            avg_latency_ms: non_neg_integer(),
            capabilities: [atom()],
            priority: integer()
          }

    defstruct [
      :id,
      :module,
      :default_model,
      models: [],
      cost_per_1k_input: 0.001,
      cost_per_1k_output: 0.002,
      avg_latency_ms: 800,
      capabilities: [:chat, :tools, :json],
      priority: 50
    ]
  end

  @default_providers %{
    openai: %Spec{
      id: :openai,
      module: Lux.LLM.OpenAI,
      default_model: "gpt-4o",
      models: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "o1", "o3-mini"],
      cost_per_1k_input: 0.0025,
      cost_per_1k_output: 0.0100,
      avg_latency_ms: 650,
      capabilities: [:chat, :tools, :json, :reasoning],
      priority: 100
    },
    anthropic: %Spec{
      id: :anthropic,
      module: Lux.LLM.Anthropic,
      default_model: "claude-3-5-sonnet-latest",
      models: ["claude-3-5-sonnet-latest", "claude-3-opus-20240229", "claude-3-5-haiku-latest"],
      cost_per_1k_input: 0.0030,
      cost_per_1k_output: 0.0150,
      avg_latency_ms: 720,
      capabilities: [:chat, :tools, :json, :long_context, :reasoning],
      priority: 95
    },
    together_ai: %Spec{
      id: :together_ai,
      module: Lux.LLM.TogetherAI,
      default_model: "mistral-7b-instruct",
      models: ["mistral-7b-instruct", "meta-llama/Llama-3-70b-chat-hf", "Qwen/Qwen2.5-72B-Instruct-Turbo"],
      cost_per_1k_input: 0.0002,
      cost_per_1k_output: 0.0002,
      avg_latency_ms: 420,
      capabilities: [:chat, :tools, :fast_inference],
      priority: 80
    },
    mira: %Spec{
      id: :mira,
      module: Lux.LLM.Mira,
      default_model: "gpt-4o-mini",
      models: ["gpt-4o-mini", "llama-3.1-70b"],
      cost_per_1k_input: 0.0004,
      cost_per_1k_output: 0.0008,
      avg_latency_ms: 500,
      capabilities: [:chat, :tools],
      priority: 70
    }
  }

  @doc """
  Ensures ETS tables for provider registry, telemetry metrics, and response cache exist.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    ensure_table(@registry_table)
    ensure_table(@metrics_table)
    ensure_table(@cache_table)

    if :ets.info(@registry_table, :size) == 0 do
      Enum.each(@default_providers, fn {id, spec} ->
        :ets.insert(@registry_table, {id, spec})
      end)
    end

    :ok
  end

  defp ensure_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  @doc """
  Registers or updates a provider specification in the runtime registry.
  """
  @spec register_provider(atom(), Spec.t() | map()) :: {:ok, Spec.t()}
  def register_provider(id, %Spec{} = spec) when is_atom(id) do
    ensure_started()
    updated = %{spec | id: id}
    :ets.insert(@registry_table, {id, updated})
    {:ok, updated}
  end

  def register_provider(id, attrs) when is_atom(id) and is_map(attrs) do
    spec = struct(Spec, Map.put(attrs, :id, id))
    register_provider(id, spec)
  end

  @doc """
  Returns a registered provider specification by its atom identifier.
  """
  @spec get_provider(atom()) :: {:ok, Spec.t()} | {:error, :not_found}
  def get_provider(id) when is_atom(id) do
    ensure_started()

    case :ets.lookup(@registry_table, id) do
      [{^id, spec}] -> {:ok, spec}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all registered LLM providers ordered by priority descending.
  """
  @spec list_providers() :: [Spec.t()]
  def list_providers do
    ensure_started()

    @registry_table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, spec} -> spec end)
    |> Enum.sort_by(& &1.priority, :desc)
  end

  @doc """
  Automatically selects the optimal provider and model based on caller criteria.

  Supported options in `criteria`:
  - `:provider` - explicit provider atom (`:openai`, `:anthropic`, `:together_ai`, `:mira`)
  - `:strategy` - `:quality` | `:cost_optimized` | `:latency_optimized` | `:balanced`
  - `:required_capabilities` - list of capability atoms (e.g. `[:reasoning, :tools]`)
  - `:max_cost_per_1k` - float upper bound on input token cost per 1k tokens
  """
  @spec select_provider(map() | keyword()) :: {:ok, Spec.t()} | {:error, :no_matching_provider}
  def select_provider(criteria \\ %{})

  def select_provider(criteria) when is_list(criteria) do
     criteria |> Enum.into(%{}) |> select_provider()
  end

  def select_provider(%{provider: provider_id} = criteria) when not is_nil(provider_id) do
    case get_provider(provider_id) do
      {:ok, spec} ->
        model = Map.get(criteria, :model, spec.default_model)
        {:ok, %{spec | default_model: model}}

      {:error, :not_found} ->
        {:error, :no_matching_provider}
    end
  end

  def select_provider(criteria) when is_map(criteria) do
    ensure_started()
    required_caps = Map.get(criteria, :required_capabilities, [])
    max_cost = Map.get(criteria, :max_cost_per_1k)
    strategy = Map.get(criteria, :strategy, :balanced)

    candidates =
      list_providers()
      |> Enum.filter(fn spec ->
        Enum.all?(required_caps, &(&1 in spec.capabilities)) and
          (is_nil(max_cost) or spec.cost_per_1k_input <= max_cost)
      end)

    case sort_by_strategy(candidates, strategy) do
      [best | _] ->
        model = Map.get(criteria, :model, best.default_model)
        {:ok, %{best | default_model: model}}

      [] ->
        {:error, :no_matching_provider}
    end
  end

  defp sort_by_strategy(specs, :cost_optimized) do
    Enum.sort_by(specs, fn s -> s.cost_per_1k_input + s.cost_per_1k_output end, :asc)
  end

  defp sort_by_strategy(specs, :latency_optimized) do
    Enum.sort_by(specs, & &1.avg_latency_ms, :asc)
  end

  defp sort_by_strategy(specs, :quality) do
    Enum.sort_by(specs, & &1.priority, :desc)
  end

  defp sort_by_strategy(specs, _balanced) do
    Enum.sort_by(specs, fn s ->
      cost_score = (s.cost_per_1k_input + s.cost_per_1k_output) * 1000.0
      latency_score = s.avg_latency_ms / 100.0
      s.priority - cost_score - latency_score
    end, :desc)
  end

  @doc """
  Executes an LLM request with automatic model selection, optional ETS response caching,
  intelligent multi-provider fallback, and real-time cost/latency telemetry.
  """
  @spec call_with_fallback(String.t(), list(), map() | keyword()) ::
          {:ok, term()} | {:error, term()}
  def call_with_fallback(prompt, tools \\ [], opts \\ %{})

  def call_with_fallback(prompt, tools, opts) when is_list(opts) do
    call_with_fallback(prompt, tools, Enum.into(opts, %{}))
  end

  def call_with_fallback(prompt, tools, opts) when is_map(opts) do
    ensure_started()
    cache_enabled = Map.get(opts, :cache, false)
    cache_key = build_cache_key(prompt, tools, opts)

    if cache_enabled do
      case lookup_cache(cache_key) do
        {:ok, cached_response} ->
          record_cache_hit()
          {:ok, cached_response}

        :miss ->
          execute_fallback_chain(prompt, tools, opts, cache_enabled, cache_key)
      end
    else
      execute_fallback_chain(prompt, tools, opts, false, cache_key)
    end
  end

  defp execute_fallback_chain(prompt, tools, opts, cache_enabled, cache_key) do
    chain = build_fallback_chain(opts)

    Enum.reduce_while(chain, {:error, :no_providers_available}, fn spec, _last_err ->
      start_time = System.monotonic_time(:millisecond)
      provider_config = build_provider_config(spec, opts)

      result =
        try do
          spec.module.call(prompt, tools, provider_config)
        rescue
          e -> {:error, Exception.message(e)}
        end

      duration_ms = max(0, System.monotonic_time(:millisecond) - start_time)

      case result do
        {:ok, response} = ok_tuple ->
          est_cost = estimate_call_cost(spec, prompt, response)
          record_call(spec.id, :ok, duration_ms, est_cost)

          if cache_enabled do
            put_cache(cache_key, response, Map.get(opts, :cache_ttl_ms, 300_000))
          end

          {:halt, ok_tuple}

        {:error, reason} = err_tuple ->
          record_call(spec.id, :error, duration_ms, 0.0)
          Logger.warning("LLM provider #{spec.id} failed (#{inspect(reason)}), attempting next fallback if available.")
          {:cont, err_tuple}
      end
    end)
  end

  defp build_fallback_chain(opts) do
    cond do
      is_list(opts[:fallback_providers]) and opts[:fallback_providers] != [] ->
        opts[:fallback_providers]
        |> Enum.map(&resolve_spec/1)
        |> Enum.reject(&is_nil/1)

      not is_nil(opts[:provider]) ->
        primary = resolve_spec(opts[:provider])
        others = list_providers() |> Enum.reject(&(&1.id == opts[:provider]))
        Enum.reject([primary | others], &is_nil/1)

      true ->
        case select_provider(opts) do
          {:ok, primary} ->
            others = list_providers() |> Enum.reject(&(&1.id == primary.id))
            [primary | others]

          {:error, _} ->
            list_providers()
        end
    end
  end

  defp resolve_spec(%Spec{} = spec), do: spec

  defp resolve_spec(id) when is_atom(id) do
    case get_provider(id) do
      {:ok, spec} -> spec
      _ -> nil
    end
  end

  defp build_provider_config(%Spec{} = spec, opts) do
    base =
      opts
      |> Map.drop([:provider, :fallback_providers, :strategy, :required_capabilities, :max_cost_per_1k, :cache, :cache_ttl_ms])

    Map.put_new(base, :model, spec.default_model)
  end

  @doc """
  Estimates token usage and USD cost for a prompt + response pair.
  """
  @spec estimate_call_cost(Spec.t(), String.t() | list(), term()) :: float()
  def estimate_call_cost(%Spec{} = spec, prompt, response) do
    input_chars =
      cond do
        is_binary(prompt) -> String.length(prompt)
        is_list(prompt) -> prompt |> inspect() |> String.length()
        true -> 100
      end

    output_chars =
      case response do
        %{payload: %{content: c}} when is_binary(c) -> String.length(c)
        %{content: c} when is_binary(c) -> String.length(c)
        other -> other |> inspect() |> String.length()
      end

    input_tokens = max(1, div(input_chars, 4))
    output_tokens = max(1, div(output_chars, 4))

    Float.round(
      input_tokens / 1000.0 * spec.cost_per_1k_input +
        output_tokens / 1000.0 * spec.cost_per_1k_output,
      6
    )
  end

  @doc """
  Records execution telemetry for a provider call.
  """
  @spec record_call(atom(), :ok | :error, non_neg_integer(), float()) :: :ok
  def record_call(provider_id, status, duration_ms, cost_usd) do
    ensure_started()

    current =
      case :ets.lookup(@metrics_table, provider_id) do
        [{^provider_id, map}] ->
          map

        [] ->
          %{
            calls: 0,
            successes: 0,
            failures: 0,
            total_latency_ms: 0,
            avg_latency_ms: 0.0,
            total_cost_usd: 0.0
          }
      end

    calls = current.calls + 1
    successes = if status == :ok, do: current.successes + 1, else: current.successes
    failures = if status == :error, do: current.failures + 1, else: current.failures
    total_latency = current.total_latency_ms + duration_ms
    total_cost = Float.round(current.total_cost_usd + cost_usd, 6)

    updated = %{
      calls: calls,
      successes: successes,
      failures: failures,
      total_latency_ms: total_latency,
      avg_latency_ms: Float.round(total_latency / calls, 2),
      total_cost_usd: total_cost
    }

    :ets.insert(@metrics_table, {provider_id, updated})
    :ok
  end

  defp record_cache_hit do
    ensure_started()

    hits =
      case :ets.lookup(@metrics_table, :__cache_hits__) do
        [{:__cache_hits__, count}] -> count + 1
        [] -> 1
      end

    :ets.insert(@metrics_table, {:__cache_hits__, hits})
  end

  @doc """
  Returns aggregated performance and cost metrics across all providers.
  """
  @spec get_metrics() :: map()
  def get_metrics do
    ensure_started()
    entries = :ets.tab2list(@metrics_table)

    cache_hits =
      case List.keyfind(entries, :__cache_hits__, 0) do
        {:__cache_hits__, count} -> count
        nil -> 0
      end

    providers_map =
      entries
      |> Enum.reject(fn {k, _v} -> k == :__cache_hits__ end)
      |> Enum.into(%{})

    total_cost =
      providers_map
      |> Map.values()
      |> Enum.reduce(0.0, fn m, acc -> Float.round(acc + m.total_cost_usd, 6) end)

    %{
      cache_hits: cache_hits,
      total_cost_usd: total_cost,
      providers: providers_map
    }
  end

  @doc """
  Resets all telemetry metrics and clears the response cache.
  """
  @spec reset_metrics() :: :ok
  def reset_metrics do
    ensure_started()
    :ets.delete_all_objects(@metrics_table)
    :ok
  end

  @doc """
  Clears all cached LLM responses.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    ensure_started()
    :ets.delete_all_objects(@cache_table)
    :ok
  end

  defp build_cache_key(prompt, tools, opts) do
    tool_names =
      Enum.map(tools, fn
        %{name: n} -> n
        other -> inspect(other)
      end)

    :erlang.phash2({prompt, tool_names, Map.drop(opts, [:cache, :cache_ttl_ms])})
  end

  defp lookup_cache(key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@cache_table, key) do
      [{^key, response, expires_at}] when expires_at > now ->
        {:ok, response}

      [{^key, _response, _expired}] ->
        :ets.delete(@cache_table, key)
        :miss

      [] ->
        :miss
    end
  end

  defp put_cache(key, response, ttl_ms) do
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@cache_table, {key, response, expires_at})
    :ok
  end
end
