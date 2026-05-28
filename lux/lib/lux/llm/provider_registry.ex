defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  Stateless registry and router for LLM provider selection.

  The registry is a plain map so applications can keep routing decisions local,
  inject custom providers in tests, or build their own supervision around it.
  """

  alias Lux.LLM.Provider

  @type registry :: %{atom() => Provider.t()}
  @type request :: %{
          optional(:capabilities) => [atom()],
          optional(:provider) => atom() | String.t(),
          optional(:model) => String.t(),
          optional(:input_tokens) => non_neg_integer(),
          optional(:output_tokens) => non_neg_integer(),
          optional(:max_cost) => number(),
          optional(:strategy) => :balanced | :cost | :latency | :quality
        }

  @default_capabilities [:chat, :tools]

  @doc """
  Returns Lux's built-in providers as a registry.
  """
  @spec default_registry() :: registry()
  def default_registry do
    [
      Provider.new(%{
        id: :open_ai,
        module: Lux.LLM.OpenAI,
        default_model: "gpt-4o-mini",
        priority: 10,
        capabilities: [:chat, :tools, :json_schema],
        models: %{
          "gpt-4o-mini" => %{
            capabilities: [:chat, :tools, :json_schema],
            input_cost_per_1k: 0.00015,
            output_cost_per_1k: 0.0006,
            context_window: 128_000,
            quality: 0.82,
            latency_ms: 900
          },
          "gpt-4o" => %{
            capabilities: [:chat, :tools, :json_schema, :vision],
            input_cost_per_1k: 0.0025,
            output_cost_per_1k: 0.01,
            context_window: 128_000,
            quality: 0.95,
            latency_ms: 1_300
          }
        }
      }),
      Provider.new(%{
        id: :anthropic,
        module: Lux.LLM.Anthropic,
        default_model: "claude-3-5-sonnet-20241022",
        priority: 20,
        capabilities: [:chat, :tools],
        models: %{
          "claude-3-5-sonnet-20241022" => %{
            capabilities: [:chat, :tools],
            input_cost_per_1k: 0.003,
            output_cost_per_1k: 0.015,
            context_window: 200_000,
            quality: 0.94,
            latency_ms: 1_400
          },
          "claude-3-haiku-20240307" => %{
            capabilities: [:chat, :tools],
            input_cost_per_1k: 0.00025,
            output_cost_per_1k: 0.00125,
            context_window: 200_000,
            quality: 0.78,
            latency_ms: 850
          }
        }
      }),
      Provider.new(%{
        id: :together_ai,
        module: Lux.LLM.TogetherAI,
        default_model: "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",
        priority: 30,
        capabilities: [:chat, :tools],
        models: %{
          "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo" => %{
            capabilities: [:chat, :tools],
            input_cost_per_1k: 0.00088,
            output_cost_per_1k: 0.00088,
            context_window: 131_000,
            quality: 0.84,
            latency_ms: 1_100
          }
        }
      }),
      Provider.new(%{
        id: :mira,
        module: Lux.LLM.Mira,
        default_model: "mira-default",
        priority: 40,
        capabilities: [:chat],
        models: %{
          "mira-default" => %{
            capabilities: [:chat],
            input_cost_per_1k: 0,
            output_cost_per_1k: 0,
            context_window: 32_000,
            quality: 0.7,
            latency_ms: 1_500
          }
        }
      })
    ]
    |> new()
  end

  @spec new([Provider.t()]) :: registry()
  def new(providers) when is_list(providers) do
    Map.new(providers, &{&1.id, &1})
  end

  @spec register(registry(), Provider.t()) :: registry()
  def register(registry, %Provider{} = provider), do: Map.put(registry, provider.id, provider)

  @spec providers(registry()) :: [Provider.t()]
  def providers(registry), do: Map.values(registry)

  @spec get(registry(), atom() | String.t()) :: {:ok, Provider.t()} | {:error, :provider_not_found}
  def get(registry, provider_id) do
    id = normalize_provider_id(provider_id)

    case Map.fetch(registry, id) do
      {:ok, provider} -> {:ok, provider}
      :error -> {:error, :provider_not_found}
    end
  end

  @doc """
  Selects the best provider/model pair for the request.
  """
  @spec select(registry(), request()) ::
          {:ok, map()} | {:error, :no_provider_available | :provider_not_found | :model_not_found}
  def select(registry, request \\ %{}) do
    request = normalize_request(request)

    registry
    |> candidate_providers(request)
    |> rank_candidates(request)
    |> case do
      [] ->
        {:error, :no_provider_available}

      [{provider, model_id, metadata} | rest] ->
        {:ok,
         %{
           provider: provider,
           model: model_id,
           model_metadata: metadata,
           fallback_chain: Enum.map(rest, fn {provider, model_id, _metadata} -> {provider.id, model_id} end),
           estimated_cost: estimate_cost!(provider, model_id, request)
         }}
    end
  end

  @doc """
  Builds an ordered fallback chain from the same selection rules.
  """
  @spec fallback_chain(registry(), request()) :: [{atom(), String.t()}]
  def fallback_chain(registry, request \\ %{}) do
    request = normalize_request(request)

    registry
    |> candidate_providers(request)
    |> rank_candidates(request)
    |> Enum.map(fn {provider, model_id, _metadata} -> {provider.id, model_id} end)
  end

  @doc """
  Produces a stable cache key for semantically identical routing requests.
  """
  @spec cache_key(request()) :: String.t()
  def cache_key(request) do
    request
    |> normalize_request()
    |> Map.take([:capabilities, :provider, :model, :strategy, :max_cost])
    |> :erlang.term_to_binary()
    |> :crypto.hash(:sha256)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Aggregates usage records into token and cost totals by provider/model.
  """
  @spec usage_summary([map()]) :: map()
  def usage_summary(records) when is_list(records) do
    Enum.reduce(records, %{total_cost: 0.0, total_input_tokens: 0, total_output_tokens: 0, by_model: %{}}, fn
      record, acc ->
        provider = normalize_provider_id(Map.get(record, :provider) || Map.get(record, "provider"))
        model = Map.get(record, :model) || Map.get(record, "model")
        key = {provider, model}
        input_tokens = Map.get(record, :input_tokens) || Map.get(record, "input_tokens") || 0
        output_tokens = Map.get(record, :output_tokens) || Map.get(record, "output_tokens") || 0
        cost = Map.get(record, :cost) || Map.get(record, "cost") || 0.0

        by_model =
          Map.update(acc.by_model, key, %{requests: 1, input_tokens: input_tokens, output_tokens: output_tokens, cost: cost}, fn current ->
            %{
              requests: current.requests + 1,
              input_tokens: current.input_tokens + input_tokens,
              output_tokens: current.output_tokens + output_tokens,
              cost: Float.round(current.cost + cost, 8)
            }
          end)

        %{
          acc
          | total_cost: Float.round(acc.total_cost + cost, 8),
            total_input_tokens: acc.total_input_tokens + input_tokens,
            total_output_tokens: acc.total_output_tokens + output_tokens,
            by_model: by_model
        }
    end)
  end

  defp candidate_providers(registry, %{provider: provider_id} = request) when not is_nil(provider_id) do
    with {:ok, provider} <- get(registry, provider_id),
         {:ok, {model_id, metadata}} <- Provider.model(provider, request.model),
         true <- candidate?(provider, model_id, metadata, request) do
      [{provider, model_id, metadata}]
    else
      {:error, :provider_not_found} -> []
      {:error, :model_not_found} -> []
      false -> []
    end
  end

  defp candidate_providers(registry, request) do
    registry
    |> providers()
    |> Enum.flat_map(fn provider ->
      provider.models
      |> Enum.filter(fn {model_id, metadata} -> candidate?(provider, model_id, metadata, request) end)
      |> Enum.map(fn {model_id, metadata} -> {provider, model_id, metadata} end)
    end)
  end

  defp candidate?(%Provider{enabled: false}, _model_id, _metadata, _request), do: false

  defp candidate?(provider, model_id, _metadata, request) do
    Provider.supports?(provider, request.capabilities, model_id) and
      within_cost_limit?(provider, model_id, request)
  end

  defp within_cost_limit?(_provider, _model_id, %{max_cost: nil}), do: true

  defp within_cost_limit?(provider, model_id, %{max_cost: max_cost} = request) do
    estimate_cost!(provider, model_id, request) <= max_cost
  end

  defp rank_candidates(candidates, %{strategy: :cost}) do
    Enum.sort_by(candidates, fn {provider, model_id, _metadata} ->
      {estimate_cost!(provider, model_id, %{input_tokens: 1_000, output_tokens: 1_000}), provider.priority}
    end)
  end

  defp rank_candidates(candidates, %{strategy: :latency}) do
    Enum.sort_by(candidates, fn {provider, _model_id, metadata} ->
      {Map.get(metadata, :latency_ms, 10_000), provider.priority}
    end)
  end

  defp rank_candidates(candidates, %{strategy: :quality}) do
    Enum.sort_by(candidates, fn {provider, _model_id, metadata} ->
      {-Map.get(metadata, :quality, 0), provider.priority}
    end)
  end

  defp rank_candidates(candidates, _request) do
    Enum.sort_by(candidates, fn {provider, _model_id, metadata} ->
      {
        provider.priority,
        Map.get(metadata, :latency_ms, 10_000),
        -Map.get(metadata, :quality, 0)
      }
    end)
  end

  defp estimate_cost!(provider, model_id, request) do
    {:ok, cost} =
      Provider.estimate_cost(
        provider,
        model_id,
        Map.get(request, :input_tokens, 0),
        Map.get(request, :output_tokens, 0)
      )

    cost
  end

  defp normalize_request(request) when is_list(request), do: request |> Map.new() |> normalize_request()

  defp normalize_request(request) when is_map(request) do
    %{
      capabilities: normalize_capabilities(Map.get(request, :capabilities) || Map.get(request, "capabilities") || @default_capabilities),
      provider: Map.get(request, :provider) || Map.get(request, "provider"),
      model: Map.get(request, :model) || Map.get(request, "model"),
      input_tokens: Map.get(request, :input_tokens) || Map.get(request, "input_tokens") || 0,
      output_tokens: Map.get(request, :output_tokens) || Map.get(request, "output_tokens") || 0,
      max_cost: Map.get(request, :max_cost) || Map.get(request, "max_cost"),
      strategy: normalize_strategy(Map.get(request, :strategy) || Map.get(request, "strategy") || :balanced)
    }
  end

  defp normalize_capabilities(capabilities) when is_binary(capabilities) do
    capabilities
    |> String.split(",", trim: true)
    |> Enum.map(&normalize_capability/1)
  end

  defp normalize_capabilities(capabilities) when is_list(capabilities) do
    Enum.map(capabilities, &normalize_capability/1)
  end

  defp normalize_capability(capability) when is_atom(capability), do: capability
  defp normalize_capability(capability) when is_binary(capability), do: capability |> String.trim() |> String.to_atom()

  defp normalize_provider_id(nil), do: nil
  defp normalize_provider_id(id) when is_atom(id), do: id
  defp normalize_provider_id(id) when is_binary(id), do: id |> String.replace("-", "_") |> String.to_atom()

  defp normalize_strategy(strategy) when is_atom(strategy), do: strategy
  defp normalize_strategy(strategy) when is_binary(strategy), do: strategy |> String.trim() |> String.to_atom()
end
