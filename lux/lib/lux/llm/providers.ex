defmodule Lux.LLM.Providers do
  @moduledoc """
  Universal LLM Provider Abstraction Layer.

  Auto-selects the best provider, handles fallback with circuit breaker,
  tracks costs and performance, and caches responses.

  ## Usage

      Lux.LLM.Providers.call("Hello", [], %{task_type: :fast})
      Lux.LLM.Providers.call("Explain AI", [], %{model: "gpt-4o"})

  ## Provider registration

  Providers register with their models, capabilities, and cost data.
  Built-in providers: `:openai`, `:anthropic`, `:together_ai`, `:mira`.
  Custom providers can be registered via `register/2` or application config.
  """

  @behaviour Lux.LLM

  alias Lux.LLM

  require Logger

  defstruct [
    :name,
    :module,
    :models,
    :capabilities,
    :cost_per_input_token,
    :cost_per_output_token,
    :priority,
    :enabled
  ]

  @registry_table :lux_llm_providers
  @circuit_table :lux_llm_circuits
  @cost_table :lux_llm_costs
  @cache_table :lux_llm_cache

  @failure_threshold 5
  @reset_timeout :timer.seconds(30)

  @doc false
  def init do
    for {table, opts} <- [
          {@registry_table, [:set, :public, :named_table]},
          {@circuit_table, [:set, :public, :named_table]},
          {@cost_table, [:ordered_set, :public, :named_table]},
          {@cache_table, [:set, :public, :named_table, read_concurrency: true]}
        ] do
      if :ets.info(table) == :undefined, do: :ets.new(table, opts)
    end

    register_defaults()
    Logger.info("Lux.LLM.Providers initialized with #{length(list_providers())} providers")
    :ok
  end

  defp register_defaults do
    register(:openai, %{
      module: LLM.OpenAI,
      models: ~w(gpt-4o gpt-4o-mini gpt-4 gpt-3.5-turbo),
      capabilities: [:tools, :structured_output, :vision],
      cost_per_input_token: %{default: 2.5e-6, "gpt-4o-mini": 0.15e-6},
      cost_per_output_token: %{default: 1e-5, "gpt-4o-mini": 0.6e-6},
      priority: 1
    })

    register(:anthropic, %{
      module: LLM.Anthropic,
      models: ~w(claude-3-opus-20240229 claude-3-sonnet-20240229 claude-3-haiku-20240307),
      capabilities: [:tools, :vision, :long_context],
      cost_per_input_token: %{default: 3e-6, "claude-3-haiku-20240307": 0.25e-6},
      cost_per_output_token: %{default: 1.5e-5, "claude-3-haiku-20240307": 1.25e-6},
      priority: 2
    })

    register(:together_ai, %{
      module: LLM.TogetherAI,
      models: ~w(mistralai/Mistral-7B-Instruct-v0.2),
      capabilities: [:tools],
      cost_per_input_token: %{default: 0.2e-6},
      cost_per_output_token: %{default: 0.2e-6},
      priority: 3
    })

    register(:mira, %{
      module: LLM.Mira,
      models: ~w(llama-3.1-8b-instruct),
      capabilities: [:tools],
      cost_per_input_token: %{default: 0.1e-6},
      cost_per_output_token: %{default: 0.1e-6},
      priority: 4
    })

    Application.get_env(:lux, :custom_providers, [])
    |> Enum.each(fn {name, config} -> register(name, config) end)
  end

  @doc """
  Registers an LLM provider.

  Options:
    - `:module` (required) - The provider module implementing `Lux.LLM`
    - `:models` - List of supported model strings
    - `:capabilities` - List of atoms like `:tools`, `:vision`, `:structured_output`
    - `:cost_per_input_token` - Map of model to cost per input token
    - `:cost_per_output_token` - Map of model to cost per output token
    - `:priority` - Lower number = higher priority (default: 99)
    - `:enabled` - Whether the provider is active (default: true)
  """
  def register(name, opts) when is_list(opts) do
    provider = struct(__MODULE__, %{
      name: name,
      module: opts[:module],
      models: opts[:models] || [],
      capabilities: opts[:capabilities] || [],
      cost_per_input_token: opts[:cost_per_input_token] || %{},
      cost_per_output_token: opts[:cost_per_output_token] || %{},
      priority: opts[:priority] || 99,
      enabled: Keyword.get(opts, :enabled, true)
    })

    :ets.insert(@registry_table, {name, provider})
    :ets.insert(@circuit_table, {name, %{state: :closed, failures: 0, last_failure: nil}})
    :ok
  end

  def register(name, opts) when is_map(opts), do: register(name, Map.to_list(opts))

  @doc """
  Unregisters a provider.
  """
  def unregister(name) do
    :ets.delete(@registry_table, name)
    :ets.delete(@circuit_table, name)
    :ok
  end

  @doc """
  Lists all registered providers, ordered by priority.
  """
  def list_providers do
    @registry_table
    |> :ets.tab2list()
    |> Enum.map(fn {_name, p} -> p end)
    |> Enum.sort_by(& &1.priority)
  end

  @doc """
  Gets a provider struct by name.
  """
  def get_provider(name) do
    case :ets.lookup(@registry_table, name) do
      [{^name, provider}] -> {:ok, provider}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Selects the best provider for the given options.

  Options:
    - `:model` - Specific model name to match
    - `:task_type` - `:general`, `:reasoning`, `:fast`, or `:cheap`
    - `:capabilities` - Required capability atoms
  """
  def select_provider(opts \\ []) do
    ensure_init!()

    model = opts[:model]
    task = opts[:task_type] || :general
    caps = opts[:capabilities] || []

    candidates = Enum.filter(list_providers(), &(&1.enabled && has_caps?(&1, caps)))

    selected =
      cond do
        model -> Enum.find(candidates, &model_match?(&1, model))
        task == :reasoning -> pick_by_keywords(candidates, ~w(opus sonnet gpt-4o gpt-4))
        task == :fast -> pick_by_keywords(candidates, ~w(mini haiku turbo))
        task == :cheap -> Enum.min_by(candidates, &cheapest_cost/1, fn -> nil end)
        true -> List.first(candidates)
      end

    selected || List.first(list_providers())
  end

  @doc """
  Returns providers ordered for fallback, excluding circuit-broken providers.
  """
  def select_fallback_chain(opts \\ []) do
    ensure_init!()

    model = opts[:model]
    caps = opts[:capabilities] || []

    list_providers()
    |> Enum.filter(&(&1.enabled && has_caps?(&1, caps) && !circuit_open?(&1.name)))
    |> then(fn ps ->
      if model do
        {match, rest} = Enum.split_with(ps, &model_match?(&1, model))
        match ++ rest
      else
        ps
      end
    end)
  end

  @doc """
  Returns whether a provider's circuit breaker is open.
  """
  def circuit_open?(name) do
    case :ets.lookup(@circuit_table, name) do
      [{^name, %{state: :open, last_failure: last_fail}}] ->
        if last_fail && System.monotonic_time(:millisecond) - last_fail > @reset_timeout do
          :ets.insert(@circuit_table, {name, %{state: :half_open, failures: 0, last_failure: nil}})
          false
        else
          true
        end

      _ ->
        false
    end
  end

  @doc """
  Records a successful call, resetting the circuit breaker.
  """
  def record_success(name) do
    :ets.insert(@circuit_table, {name, %{state: :closed, failures: 0, last_failure: nil}})
  end

  @doc """
  Records a failure, potentially opening the circuit breaker.
  """
  def record_failure(name) do
    case :ets.lookup(@circuit_table, name) do
      [{^name, %{failures: f} = state}] ->
        f2 = f + 1
        new_state =
          if f2 >= @failure_threshold,
            do: :open,
            else: state.state

        :ets.insert(@circuit_table, {name, %{state: new_state, failures: f2, last_failure: System.monotonic_time(:millisecond)}})

        if new_state == :open do
          Logger.warning("[Lux.LLM.Providers] Circuit breaker opened for #{inspect(name)} after #{f2} failures")
        end

      _ ->
        :ok
    end
  end

  @doc """
  Tracks cost and performance of an LLM call.
  """
  def track_cost(provider, model, prompt_tokens, completion_tokens, latency_ms, success?) do
    :ets.insert(@cost_table, {
      System.unique_integer([:positive, :monotonic]),
      %{
        provider: provider,
        model: model,
        prompt_tokens: prompt_tokens || 0,
        completion_tokens: completion_tokens || 0,
        latency_ms: latency_ms || 0,
        success: success?,
        timestamp: DateTime.utc_now()
      }
    })
  end

  @doc """
  Returns aggregated cost and performance statistics.

  Options:
    - `:provider` - Filter by provider atom
    - `:since` - Filter by `%DateTime{}`
  """
  def get_stats(opts \\ []) do
    entries =
      @cost_table
      |> :ets.tab2list()
      |> Enum.map(fn {_id, e} -> e end)
      |> maybe_filter(:provider, opts[:provider])
      |> maybe_filter(:since, opts[:since])

    total = length(entries)
    ok = Enum.count(entries, & &1.success)
    ptokens = Enum.sum_by(entries, & &1.prompt_tokens)
    ctokens = Enum.sum_by(entries, & &1.completion_tokens)
    lats = Enum.map(entries, & &1.latency_ms)

    %{
      total_requests: total,
      successful: ok,
      failed: total - ok,
      success_rate: if(total > 0, do: ok / total, else: 0.0),
      total_prompt_tokens: ptokens,
      total_completion_tokens: ctokens,
      total_tokens: ptokens + ctokens,
      avg_latency_ms: if(lats != [], do: Enum.sum(lats) / length(lats), else: 0.0),
      by_provider:
        entries
        |> Enum.group_by(& &1.provider)
        |> Enum.map(fn {k, v} ->
          {k,
           %{
             count: length(v),
             tokens: Enum.sum_by(v, &(&1.prompt_tokens + &1.completion_tokens)),
             avg_latency_ms: Enum.sum_by(v, & &1.latency_ms) / max(length(v), 1)
           }}
        end)
        |> Map.new()
    }
  end

  defp maybe_filter(entries, _key, nil), do: entries

  defp maybe_filter(entries, :provider, val),
    do: Enum.filter(entries, &(&1.provider == val))

  defp maybe_filter(entries, :since, val),
    do: Enum.filter(entries, &(DateTime.compare(&1.timestamp, val) != :lt))

  @doc """
  Caches an LLM response for a given key.
  """
  def cache_response(key, response, ttl \\ :timer.minutes(5)) do
    :ets.insert(@cache_table, {cache_hash(key), %{response: response, expires_at: System.monotonic_time(:millisecond) + ttl}})
  end

  @doc """
  Retrieves a cached response.
  """
  def get_cached(key) do
    case :ets.lookup(@cache_table, cache_hash(key)) do
      [{_hk, %{response: r, expires_at: exp}}] when exp > System.monotonic_time(:millisecond) ->
        {:ok, r}

      [{_hk, _}] ->
        :ets.delete(@cache_table, cache_hash(key))
        {:error, :expired}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Flushes the cache. Pass `:all` or a specific key.
  """
  def flush_cache(:all), do: :ets.delete_all_objects(@cache_table)
  def flush_cache(key), do: :ets.delete(@cache_table, cache_hash(key))

  @doc false
  def reset_all do
    for table <- [@registry_table, @circuit_table, @cost_table, @cache_table] do
      if :ets.info(table) != :undefined do
        :ets.delete(table)
      end
    end
  end

  @impl true
  def call(prompt, tools \\ [], options \\ %{}) do
    opts = normalize_opts(options)
    cache_key = "#{prompt}|#{inspect(tools)}|#{opts[:model] || :any}"

    if Keyword.get(opts, :cache, true) do
      case get_cached(cache_key) do
        {:ok, response} -> {:ok, response}
        _ -> do_call_with_fallback(prompt, tools, opts, cache_key)
      end
    else
      do_call_with_fallback(prompt, tools, opts, cache_key)
    end
  end

  defp do_call_with_fallback(prompt, tools, opts, cache_key) do
    chain = select_fallback_chain(opts)

    if chain == [] do
      {:error, "No LLM providers available"}
    else
      try_chain(chain, prompt, tools, opts, cache_key)
    end
  end

  defp try_chain([p | rest], prompt, tools, opts, cache_key) do
    start = System.monotonic_time(:millisecond)
    model = opts[:model] || List.first(p.models)

    result =
      case p.module.call(prompt, tools, Map.put(opts, :model, model)) do
        {:ok, _signal} = ok -> ok
        {:ok, _response} = ok -> ok
        {:error, _reason} = err -> err
        other -> {:error, "Unexpected response from #{p.name}: #{inspect(other)}"}
      end

    case result do
      {:ok, response} ->
        record_success(p.name)
        track_cost(p.name, model, 0, 0, System.monotonic_time(:millisecond) - start, true)
        if Keyword.get(opts, :cache, true), do: cache_response(cache_key, response)
        {:ok, response}

      {:error, reason} ->
        record_failure(p.name)
        track_cost(p.name, model, 0, 0, System.monotonic_time(:millisecond) - start, false)
        Logger.warning("[Lux.LLM.Providers] #{p.name} failed: #{inspect(reason)}")

        case rest do
          [] -> {:error, "All providers exhausted. Last: #{inspect(reason)}"}
          _ -> try_chain(rest, prompt, tools, opts, cache_key)
        end
    end
  end

  defp ensure_init! do
    if :ets.info(@registry_table) == :undefined, do: init()
  end

  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)

  defp has_caps?(provider, []), do: true

  defp has_caps?(provider, caps),
    do: Enum.all?(caps, &(&1 in (provider.capabilities || [])))

  defp model_match?(provider, model_name) do
    Enum.any?(provider.models, fn m ->
      String.contains?(model_name, m) or String.contains?(m, model_name)
    end)
  end

  defp pick_by_keywords(candidates, keywords) do
    Enum.find(candidates, fn p ->
      Enum.any?(p.models, fn m ->
        Enum.any?(keywords, &String.contains?(m, &1))
      end)
    end)
  end

  defp cheapest_cost(p) do
    p.cost_per_input_token
    |> Map.values()
    |> then(fn vals -> if vals == [], do: 0, else: Enum.min(vals) end)
  end

  defp cache_hash(key) when is_binary(key), do: :erlang.md5(key)
  defp cache_hash(key), do: :erlang.md5(inspect(key))
end
