defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  Registry and selection helpers for LLM providers.

  The registry is intentionally provider-client agnostic. It stores provider and
  model metadata, then builds deterministic selection and fallback plans that
  existing `Lux.LLM` provider modules can execute.
  """

  defmodule Model do
    @moduledoc "Metadata for one provider model."

    @type t :: %__MODULE__{
            id: String.t(),
            capabilities: [atom()],
            context_window: pos_integer() | nil,
            input_cost_per_million: non_neg_integer() | float() | nil,
            output_cost_per_million: non_neg_integer() | float() | nil,
            latency_ms: non_neg_integer() | nil,
            metadata: map()
          }

    defstruct [
      :id,
      :context_window,
      :input_cost_per_million,
      :output_cost_per_million,
      :latency_ms,
      capabilities: [],
      metadata: %{}
    ]
  end

  defmodule Provider do
    @moduledoc "Metadata for one LLM provider."

    @type t :: %__MODULE__{
            name: atom(),
            module: module(),
            default_model: String.t(),
            priority: integer(),
            models: %{String.t() => Model.t()},
            status: :available | :degraded | :disabled,
            metadata: map()
          }

    defstruct [
      :name,
      :module,
      :default_model,
      priority: 100,
      models: %{},
      status: :available,
      metadata: %{}
    ]
  end

  @type registry :: %{atom() => Provider.t()}
  @type usage :: %{
          optional(:input_tokens) => non_neg_integer(),
          optional(:output_tokens) => non_neg_integer()
        }

  @doc """
  Returns the built-in provider registry for Lux's current provider modules.
  """
  @spec default_registry() :: registry()
  def default_registry do
    %{}
    |> register(:openai, Lux.LLM.OpenAI,
      default_model: "gpt-4o-mini",
      priority: 10,
      models: [
        model("gpt-4o-mini",
          capabilities: [:chat, :tools, :json, :vision],
          context_window: 128_000,
          input_cost_per_million: 0.15,
          output_cost_per_million: 0.60,
          latency_ms: 900
        ),
        model("gpt-4o",
          capabilities: [:chat, :tools, :json, :vision],
          context_window: 128_000,
          input_cost_per_million: 2.50,
          output_cost_per_million: 10.00,
          latency_ms: 1_200
        )
      ]
    )
    |> register(:anthropic, Lux.LLM.Anthropic,
      default_model: "claude-3-5-haiku-latest",
      priority: 20,
      models: [
        model("claude-3-5-haiku-latest",
          capabilities: [:chat, :tools, :json],
          context_window: 200_000,
          input_cost_per_million: 0.80,
          output_cost_per_million: 4.00,
          latency_ms: 1_000
        ),
        model("claude-3-5-sonnet-latest",
          capabilities: [:chat, :tools, :json, :reasoning],
          context_window: 200_000,
          input_cost_per_million: 3.00,
          output_cost_per_million: 15.00,
          latency_ms: 1_500
        )
      ]
    )
    |> register(:together_ai, Lux.LLM.TogetherAI,
      default_model: "meta-llama/Llama-3.3-70B-Instruct-Turbo",
      priority: 30,
      models: [
        model("meta-llama/Llama-3.3-70B-Instruct-Turbo",
          capabilities: [:chat, :json],
          context_window: 131_072,
          input_cost_per_million: 0.88,
          output_cost_per_million: 0.88,
          latency_ms: 1_400
        )
      ]
    )
    |> register(:mira, Lux.LLM.Mira,
      default_model: "mira-default",
      priority: 40,
      models: [
        model("mira-default",
          capabilities: [:chat],
          input_cost_per_million: 0.0,
          output_cost_per_million: 0.0,
          latency_ms: 1_800
        )
      ]
    )
  end

  @doc """
  Creates a model descriptor.
  """
  @spec model(String.t(), keyword()) :: Model.t()
  def model(id, opts \\ []) do
    struct!(
      Model,
      opts
      |> Keyword.put(:id, id)
      |> Keyword.update(:capabilities, [], &Enum.uniq/1)
    )
  end

  @doc """
  Registers a provider and its model metadata.
  """
  @spec register(registry(), atom(), module(), keyword()) :: registry()
  def register(registry, name, module, opts \\ []) do
    models =
      opts
      |> Keyword.get(:models, [])
      |> Enum.map(fn %Model{id: id} = model -> {id, model} end)
      |> Map.new()

    provider =
      %Provider{
        name: name,
        module: module,
        default_model: Keyword.get(opts, :default_model),
        priority: Keyword.get(opts, :priority, 100),
        models: models,
        status: Keyword.get(opts, :status, :available),
        metadata: Keyword.get(opts, :metadata, %{})
      }

    Map.put(registry, name, provider)
  end

  @doc """
  Selects the best provider/model pair for a request.
  """
  @spec select(keyword() | registry(), keyword()) ::
          {:ok, map()} | {:error, :no_provider_available}
  def select(opts) when is_list(opts), do: select(default_registry(), opts)
  def select(registry) when is_map(registry), do: select(registry, [])

  def select(registry, opts) do
    registry
    |> candidates(opts)
    |> sort_candidates(Keyword.get(opts, :sort, :priority))
    |> List.first()
    |> case do
      nil -> {:error, :no_provider_available}
      candidate -> {:ok, candidate}
    end
  end

  @doc """
  Builds an ordered fallback plan for a request.
  """
  @spec fallback_plan(keyword() | registry(), keyword()) :: [map()]
  def fallback_plan(opts) when is_list(opts), do: fallback_plan(default_registry(), opts)
  def fallback_plan(registry) when is_map(registry), do: fallback_plan(registry, [])

  def fallback_plan(registry, opts) do
    registry
    |> candidates(opts)
    |> sort_candidates(Keyword.get(opts, :sort, :priority))
  end

  @doc """
  Estimates request cost in USD from model metadata and token usage.
  """
  @spec estimate_cost(Model.t() | map(), usage()) :: float()
  def estimate_cost(%Model{} = model, usage) do
    input_tokens = Map.get(usage, :input_tokens, Map.get(usage, "input_tokens", 0))
    output_tokens = Map.get(usage, :output_tokens, Map.get(usage, "output_tokens", 0))

    input_cost = (model.input_cost_per_million || 0) * input_tokens / 1_000_000
    output_cost = (model.output_cost_per_million || 0) * output_tokens / 1_000_000

    Float.round(input_cost + output_cost, 8)
  end

  def estimate_cost(%{model: %Model{} = model}, usage), do: estimate_cost(model, usage)

  @doc """
  Adds cost and latency observations to a selected candidate.
  """
  @spec usage_summary(map(), usage()) :: map()
  def usage_summary(%{model: %Model{} = model} = candidate, usage) do
    %{
      provider: candidate.provider.name,
      model: model.id,
      estimated_cost_usd: estimate_cost(model, usage),
      input_tokens: Map.get(usage, :input_tokens, Map.get(usage, "input_tokens", 0)),
      output_tokens: Map.get(usage, :output_tokens, Map.get(usage, "output_tokens", 0)),
      latency_ms: Map.get(usage, :latency_ms, Map.get(usage, "latency_ms", model.latency_ms))
    }
  end

  defp candidates(registry, opts) do
    required_capabilities = Keyword.get(opts, :capabilities, [])
    provider_filter = Keyword.get(opts, :provider)
    model_filter = Keyword.get(opts, :model)
    max_cost = Keyword.get(opts, :max_estimated_cost_usd)
    usage = Keyword.get(opts, :usage, %{})

    registry
    |> Map.values()
    |> Enum.filter(&(&1.status == :available))
    |> Enum.filter(fn provider -> is_nil(provider_filter) or provider.name == provider_filter end)
    |> Enum.flat_map(fn provider ->
      provider.models
      |> Map.values()
      |> Enum.filter(fn model -> is_nil(model_filter) or model.id == model_filter end)
      |> Enum.filter(&supports?(&1, required_capabilities))
      |> Enum.map(fn model -> %{provider: provider, model: model, module: provider.module} end)
    end)
    |> Enum.filter(fn candidate ->
      is_nil(max_cost) or estimate_cost(candidate.model, usage) <= max_cost
    end)
  end

  defp supports?(%Model{capabilities: capabilities}, required) do
    Enum.all?(required, &(&1 in capabilities))
  end

  defp sort_candidates(candidates, :cost) do
    Enum.sort_by(candidates, fn candidate ->
      {candidate.model.input_cost_per_million || 0, candidate.provider.priority}
    end)
  end

  defp sort_candidates(candidates, :latency) do
    Enum.sort_by(candidates, fn candidate ->
      {candidate.model.latency_ms || 999_999, candidate.provider.priority}
    end)
  end

  defp sort_candidates(candidates, _priority) do
    Enum.sort_by(candidates, fn candidate ->
      {candidate.provider.priority, candidate.model.input_cost_per_million || 0}
    end)
  end
end
