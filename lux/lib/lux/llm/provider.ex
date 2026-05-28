defmodule Lux.LLM.Provider do
  @moduledoc """
  Metadata and helpers for routing requests across LLM providers.

  A provider describes one backend module plus the models it can serve. The
  router can use this metadata for capability matching, cost estimates, and
  fallback planning without requiring credentials or network calls.
  """

  @type model_id :: String.t()
  @type capability :: atom()

  @type model :: %{
          optional(:capabilities) => [capability()],
          optional(:input_cost_per_1k) => number(),
          optional(:output_cost_per_1k) => number(),
          optional(:context_window) => pos_integer(),
          optional(:quality) => number(),
          optional(:latency_ms) => non_neg_integer()
        }

  @type t :: %__MODULE__{
          id: atom(),
          module: module(),
          default_model: model_id(),
          models: %{model_id() => model()},
          capabilities: [capability()],
          priority: integer(),
          enabled: boolean(),
          config: map()
        }

  defstruct id: nil,
            module: nil,
            default_model: nil,
            models: %{},
            capabilities: [],
            priority: 100,
            enabled: true,
            config: %{}

  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    models = normalize_models(Map.get(attrs, :models, %{}))
    default_model = Map.get(attrs, :default_model) || first_model(models)

    %__MODULE__{
      id: Map.fetch!(attrs, :id),
      module: Map.fetch!(attrs, :module),
      default_model: default_model,
      models: models,
      capabilities: Map.get(attrs, :capabilities, []),
      priority: Map.get(attrs, :priority, 100),
      enabled: Map.get(attrs, :enabled, true),
      config: Map.get(attrs, :config, %{})
    }
  end

  @spec model(t(), model_id() | nil) :: {:ok, {model_id(), model()}} | {:error, :model_not_found}
  def model(%__MODULE__{} = provider, model_id \\ nil) do
    id = model_id || provider.default_model

    case Map.fetch(provider.models, id) do
      {:ok, metadata} -> {:ok, {id, metadata}}
      :error -> {:error, :model_not_found}
    end
  end

  @spec supports?(t(), [capability()]) :: boolean()
  def supports?(provider, capabilities), do: supports?(provider, capabilities, nil)

  @spec supports?(t(), [capability()], model_id() | nil) :: boolean()
  def supports?(%__MODULE__{enabled: false}, _capabilities, _model_id), do: false

  def supports?(%__MODULE__{} = provider, capabilities, model_id) do
    with {:ok, {_id, metadata}} <- model(provider, model_id) do
      supported = Map.get(metadata, :capabilities, provider.capabilities)
      Enum.all?(capabilities, &(&1 in supported))
    else
      _ -> false
    end
  end

  @spec estimate_cost(t(), model_id() | nil, non_neg_integer(), non_neg_integer()) ::
          {:ok, float()} | {:error, :model_not_found}
  def estimate_cost(%__MODULE__{} = provider, model_id, input_tokens, output_tokens) do
    with {:ok, {_id, metadata}} <- model(provider, model_id) do
      input_cost = Map.get(metadata, :input_cost_per_1k, 0) * input_tokens / 1_000
      output_cost = Map.get(metadata, :output_cost_per_1k, 0) * output_tokens / 1_000
      {:ok, Float.round(input_cost + output_cost, 8)}
    end
  end

  defp normalize_models(models) do
    Map.new(models, fn {model_id, metadata} -> {to_string(model_id), metadata} end)
  end

  defp first_model(models) do
    models
    |> Map.keys()
    |> List.first()
  end
end
