defmodule Lux.LLM.ProviderRouter do
  @moduledoc """
  Stateless provider routing, fallback, cost, performance, and cache planning.

  The router builds deterministic plans over provider metadata. It does not call
  remote LLM APIs or keep runtime state; callers can use the returned plan to
  dispatch through the existing provider clients.
  """

  @default_providers [
    %{
      id: :openai,
      module: Lux.LLM.OpenAI,
      models: [
        %{
          id: "gpt-4o-mini",
          capabilities: [:chat, :tools, :json, :low_cost],
          input_cost_per_million: 0.15,
          output_cost_per_million: 0.60,
          latency_ms: 900,
          quality: 0.78
        },
        %{
          id: "gpt-4o",
          capabilities: [:chat, :tools, :json, :vision, :reasoning],
          input_cost_per_million: 5.00,
          output_cost_per_million: 15.00,
          latency_ms: 1400,
          quality: 0.91
        }
      ],
      priority: 10,
      available?: true
    },
    %{
      id: :anthropic,
      module: Lux.LLM.Anthropic,
      models: [
        %{
          id: "claude-3-5-haiku-latest",
          capabilities: [:chat, :tools, :json, :low_cost],
          input_cost_per_million: 0.80,
          output_cost_per_million: 4.00,
          latency_ms: 1000,
          quality: 0.80
        },
        %{
          id: "claude-3-5-sonnet-latest",
          capabilities: [:chat, :tools, :json, :reasoning],
          input_cost_per_million: 3.00,
          output_cost_per_million: 15.00,
          latency_ms: 1600,
          quality: 0.92
        }
      ],
      priority: 20,
      available?: true
    },
    %{
      id: :together_ai,
      module: Lux.LLM.TogetherAI,
      models: [
        %{
          id: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
          capabilities: [:chat, :tools, :low_cost],
          input_cost_per_million: 0.88,
          output_cost_per_million: 0.88,
          latency_ms: 1100,
          quality: 0.82
        }
      ],
      priority: 30,
      available?: true
    },
    %{
      id: :mira,
      module: Lux.LLM.Mira,
      models: [
        %{
          id: "llama-3.1-8b-instruct",
          capabilities: [:chat, :low_cost],
          input_cost_per_million: 0.10,
          output_cost_per_million: 0.10,
          latency_ms: 800,
          quality: 0.62
        }
      ],
      priority: 40,
      available?: true
    }
  ]

  @doc "Returns the built-in provider metadata."
  @spec providers() :: [map()]
  def providers, do: @default_providers

  @doc "Builds a provider routing plan from request constraints."
  @spec route(map()) :: map()
  def route(attrs \\ %{}) when is_map(attrs) do
    attrs = normalize_keys(attrs)
    providers = attrs |> Map.get(:providers, providers()) |> normalize_providers()
    requirements = requirements(attrs)

    candidates =
      providers |> candidate_models(requirements) |> rank_candidates(requirements.strategy)

    selected = List.first(candidates)

    %{
      selected: selected,
      candidates: candidates,
      fallback_chain: fallback_chain(candidates, selected),
      requirements: requirements,
      estimated_cost: estimate_selected_cost(selected, requirements),
      cache: cache_plan(attrs, selected),
      optimization: optimization_plan(candidates, requirements),
      coverage: [
        :universal_provider_interface,
        :provider_registry_management,
        :automatic_model_selection,
        :smart_fallback_handling,
        :cost_tracking_and_optimization,
        :performance_monitoring,
        :cache_planning
      ]
    }
  end

  @doc "Summarizes provider usage events for cost and performance monitoring."
  @spec usage_summary([map()]) :: map()
  def usage_summary(events) when is_list(events) do
    events = Enum.map(events, &normalize_keys/1)
    grouped = Enum.group_by(events, &Map.get(&1, :provider, :unknown))

    by_provider =
      Map.new(grouped, fn {provider, provider_events} ->
        latencies =
          provider_events |> Enum.map(&money(Map.get(&1, :latency_ms))) |> Enum.filter(&number?/1)

        costs =
          provider_events |> Enum.map(&money(Map.get(&1, :cost_usd))) |> Enum.filter(&number?/1)

        successes =
          Enum.count(provider_events, &(Map.get(&1, :status, :ok) in [:ok, "ok", "success"]))

        {provider,
         %{
           requests: length(provider_events),
           successes: successes,
           failures: length(provider_events) - successes,
           average_latency_ms: average(latencies),
           total_cost_usd: sum(costs)
         }}
      end)

    %{
      total_requests: length(events),
      total_cost_usd: by_provider |> Map.values() |> Enum.map(& &1.total_cost_usd) |> sum(),
      providers: by_provider
    }
  end

  @doc "Builds a stable cache key for a request and selected provider/model."
  @spec cache_key(map()) :: String.t()
  def cache_key(attrs) when is_map(attrs) do
    attrs = normalize_keys(attrs)

    payload =
      %{
        prompt: Map.get(attrs, :prompt, ""),
        tools: Map.get(attrs, :tools, []),
        provider: Map.get(attrs, :provider, ""),
        model: Map.get(attrs, :model, ""),
        temperature: Map.get(attrs, :temperature, nil),
        response_format: Map.get(attrs, :response_format, nil)
      }
      |> :erlang.term_to_binary()

    :crypto.hash(:sha256, payload)
    |> Base.encode16(case: :lower)
  end

  @doc "Estimates cost in USD for a provider model and token plan."
  @spec estimate_cost(map() | nil, map()) :: map()
  def estimate_cost(nil, _requirements), do: %{input_usd: nil, output_usd: nil, total_usd: nil}

  def estimate_cost(candidate, requirements) do
    input_tokens = Map.get(requirements, :estimated_input_tokens, 0)
    output_tokens = Map.get(requirements, :estimated_output_tokens, 0)
    model = candidate.model

    input_usd = input_tokens / 1_000_000 * model.input_cost_per_million
    output_usd = output_tokens / 1_000_000 * model.output_cost_per_million

    %{
      provider: candidate.provider_id,
      model: model.id,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      input_usd: round_money(input_usd),
      output_usd: round_money(output_usd),
      total_usd: round_money(input_usd + output_usd)
    }
  end

  defp requirements(attrs) do
    %{
      model: Map.get(attrs, :model),
      capabilities: attrs |> list(:capabilities, [:chat]) |> Enum.map(&to_atom/1),
      strategy: attrs |> Map.get(:strategy, :balanced) |> to_atom(),
      preferred_provider: attrs |> Map.get(:preferred_provider) |> maybe_atom(),
      denied_providers: attrs |> list(:denied_providers, []) |> Enum.map(&to_atom/1),
      estimated_input_tokens: integer(Map.get(attrs, :estimated_input_tokens, 1_000)),
      estimated_output_tokens: integer(Map.get(attrs, :estimated_output_tokens, 500)),
      max_cost_usd: money(Map.get(attrs, :max_cost_usd)),
      max_latency_ms: integer(Map.get(attrs, :max_latency_ms, 0))
    }
  end

  defp candidate_models(providers, requirements) do
    providers
    |> Enum.filter(& &1.available?)
    |> Enum.reject(&(&1.id in requirements.denied_providers))
    |> Enum.flat_map(fn provider ->
      provider.models
      |> Enum.filter(&model_matches?(&1, requirements))
      |> Enum.map(&candidate(provider, &1, requirements))
    end)
    |> Enum.filter(&within_limits?(&1, requirements))
  end

  defp model_matches?(model, %{model: wanted}) when is_binary(wanted) and wanted != "" do
    model.id == wanted
  end

  defp model_matches?(model, requirements) do
    Enum.all?(requirements.capabilities, &(&1 in model.capabilities))
  end

  defp candidate(provider, model, requirements) do
    cost = estimate_cost(%{provider_id: provider.id, model: model}, requirements)

    %{
      provider_id: provider.id,
      module: provider.module,
      model: model,
      priority: provider.priority,
      estimated_cost_usd: cost.total_usd,
      latency_ms: model.latency_ms,
      quality: model.quality,
      score: score(provider, model, cost.total_usd, requirements.strategy)
    }
  end

  defp within_limits?(candidate, requirements) do
    cost_ok? =
      is_nil(requirements.max_cost_usd) or
        candidate.estimated_cost_usd <= requirements.max_cost_usd

    latency_ok? =
      requirements.max_latency_ms == 0 or candidate.latency_ms <= requirements.max_latency_ms

    preferred_ok? =
      is_nil(requirements.preferred_provider) or
        candidate.provider_id == requirements.preferred_provider

    cost_ok? and latency_ok? and preferred_ok?
  end

  defp rank_candidates(candidates, _strategy) do
    candidates
    |> Enum.sort_by(&{&1.score, &1.priority, &1.provider_id, &1.model.id})
  end

  defp score(provider, model, cost, :cost),
    do: {cost, model.latency_ms, -model.quality, provider.priority}

  defp score(provider, model, _cost, :latency),
    do: {model.latency_ms, -model.quality, provider.priority}

  defp score(provider, model, _cost, :quality),
    do: {-model.quality, model.latency_ms, provider.priority}

  defp score(provider, model, cost, _strategy) do
    normalized_latency = model.latency_ms / 1000
    normalized_quality_penalty = 1 - model.quality

    {cost + normalized_latency + normalized_quality_penalty + provider.priority / 100,
     provider.priority}
  end

  defp fallback_chain(candidates, nil), do: Enum.take(candidates, 5)

  defp fallback_chain(candidates, selected) do
    candidates
    |> Enum.reject(&(&1.provider_id == selected.provider_id and &1.model.id == selected.model.id))
    |> Enum.take(5)
  end

  defp estimate_selected_cost(nil, requirements), do: estimate_cost(nil, requirements)
  defp estimate_selected_cost(selected, requirements), do: estimate_cost(selected, requirements)

  defp cache_plan(attrs, nil) do
    %{
      enabled?: Map.get(attrs, :cache_enabled?, true),
      key: nil,
      ttl_seconds: integer(Map.get(attrs, :cache_ttl_seconds, 300)),
      reason: :no_selected_provider
    }
  end

  defp cache_plan(attrs, selected) do
    cache_attrs =
      attrs
      |> Map.put(:provider, selected.provider_id)
      |> Map.put(:model, selected.model.id)

    %{
      enabled?: Map.get(attrs, :cache_enabled?, true),
      key: cache_key(cache_attrs),
      ttl_seconds: integer(Map.get(attrs, :cache_ttl_seconds, 300)),
      reason: :deterministic_request_signature
    }
  end

  defp optimization_plan(candidates, requirements) do
    cheapest = candidates |> Enum.sort_by(& &1.estimated_cost_usd) |> List.first()
    fastest = candidates |> Enum.sort_by(& &1.latency_ms) |> List.first()
    highest_quality = candidates |> Enum.sort_by(& &1.quality, :desc) |> List.first()

    %{
      strategy: requirements.strategy,
      cheapest: provider_summary(cheapest),
      fastest: provider_summary(fastest),
      highest_quality: provider_summary(highest_quality),
      rejected_by_budget?: candidates == [] and not is_nil(requirements.max_cost_usd)
    }
  end

  defp provider_summary(nil), do: nil

  defp provider_summary(candidate) do
    %{
      provider_id: candidate.provider_id,
      model: candidate.model.id,
      estimated_cost_usd: candidate.estimated_cost_usd,
      latency_ms: candidate.latency_ms,
      quality: candidate.quality
    }
  end

  defp normalize_providers(providers) when is_list(providers) do
    Enum.map(providers, fn provider ->
      provider = normalize_keys(provider)

      %{
        id: provider |> Map.get(:id, :unknown) |> to_atom(),
        module: Map.get(provider, :module),
        priority: integer(Map.get(provider, :priority, 100)),
        available?: Map.get(provider, :available?, true),
        models: provider |> Map.get(:models, []) |> normalize_models()
      }
    end)
  end

  defp normalize_models(models) when is_list(models) do
    Enum.map(models, fn model ->
      model = normalize_keys(model)

      %{
        id: to_string(Map.get(model, :id, "")),
        capabilities: model |> list(:capabilities, []) |> Enum.map(&to_atom/1),
        input_cost_per_million: money(Map.get(model, :input_cost_per_million)) || 0.0,
        output_cost_per_million: money(Map.get(model, :output_cost_per_million)) || 0.0,
        latency_ms: integer(Map.get(model, :latency_ms, 1000)),
        quality: money(Map.get(model, :quality)) || 0.5
      }
    end)
  end

  defp list(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_list(value) -> value
      value when is_binary(value) -> [value]
      value when is_atom(value) -> [value]
      _ -> default
    end
  end

  defp normalize_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {known_key(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp normalize_keys(value), do: value

  defp known_key("id"), do: :id
  defp known_key("module"), do: :module
  defp known_key("models"), do: :models
  defp known_key("priority"), do: :priority
  defp known_key("available?"), do: :available?
  defp known_key("capabilities"), do: :capabilities
  defp known_key("input_cost_per_million"), do: :input_cost_per_million
  defp known_key("output_cost_per_million"), do: :output_cost_per_million
  defp known_key("latency_ms"), do: :latency_ms
  defp known_key("quality"), do: :quality
  defp known_key("providers"), do: :providers
  defp known_key("model"), do: :model
  defp known_key("strategy"), do: :strategy
  defp known_key("preferred_provider"), do: :preferred_provider
  defp known_key("denied_providers"), do: :denied_providers
  defp known_key("estimated_input_tokens"), do: :estimated_input_tokens
  defp known_key("estimated_output_tokens"), do: :estimated_output_tokens
  defp known_key("max_cost_usd"), do: :max_cost_usd
  defp known_key("max_latency_ms"), do: :max_latency_ms
  defp known_key("cache_enabled?"), do: :cache_enabled?
  defp known_key("cache_ttl_seconds"), do: :cache_ttl_seconds
  defp known_key("prompt"), do: :prompt
  defp known_key("tools"), do: :tools
  defp known_key("provider"), do: :provider
  defp known_key("temperature"), do: :temperature
  defp known_key("response_format"), do: :response_format
  defp known_key("status"), do: :status
  defp known_key("cost_usd"), do: :cost_usd
  defp known_key(key), do: key

  defp maybe_atom(nil), do: nil
  defp maybe_atom(value), do: to_atom(value)

  defp to_atom(value) when is_atom(value), do: value
  defp to_atom(value) when is_binary(value), do: known_atom(String.downcase(value))
  defp to_atom(value), do: value |> to_string() |> String.downcase() |> known_atom()

  defp known_atom("openai"), do: :openai
  defp known_atom("anthropic"), do: :anthropic
  defp known_atom("together_ai"), do: :together_ai
  defp known_atom("together"), do: :together_ai
  defp known_atom("mira"), do: :mira
  defp known_atom("local"), do: :local
  defp known_atom("chat"), do: :chat
  defp known_atom("tools"), do: :tools
  defp known_atom("json"), do: :json
  defp known_atom("vision"), do: :vision
  defp known_atom("reasoning"), do: :reasoning
  defp known_atom("low_cost"), do: :low_cost
  defp known_atom("cost"), do: :cost
  defp known_atom("latency"), do: :latency
  defp known_atom("quality"), do: :quality
  defp known_atom("balanced"), do: :balanced
  defp known_atom(value), do: value

  defp money(nil), do: nil
  defp money(value) when is_integer(value), do: value * 1.0
  defp money(value) when is_float(value), do: value

  defp money(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp money(_), do: nil

  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: round(value)

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _rest} -> number
      :error -> 0
    end
  end

  defp integer(_), do: 0

  defp number?(value), do: is_integer(value) or is_float(value)
  defp sum(values), do: values |> Enum.sum() |> round_money()
  defp average([]), do: nil
  defp average(values), do: values |> Enum.sum() |> Kernel./(length(values)) |> round_money()
  defp round_money(value), do: Float.round(value * 1.0, 8)
end
