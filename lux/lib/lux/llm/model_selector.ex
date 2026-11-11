defmodule Lux.LLM.ModelSelector do
  @moduledoc """
  Automatic model selection engine that chooses the best LLM provider and model
  based on task complexity, required capabilities, cost ceiling, and latency preference.
  """

  alias Lux.LLM.ProviderRegistry

  @type selection :: %{
          provider_id: atom(),
          module: module(),
          model: String.t(),
          metadata: map()
        }

  @doc """
  Selects the optimal `{provider_id, module, model, metadata}` for the given options map.

  Supported options:
  - `:provider` - Explicit provider atom (e.g. `:open_ai`, `:anthropic`, `:together_ai`, `:mira`)
  - `:model` - Explicit model name
  - `:complexity` - `:low` | `:medium` | `:high` (defaults to `:medium`)
  - `:required_capabilities` - list of capability atoms (e.g. `[:tool_use, :structured_output]`)
  - `:max_cost_per_1k` - maximum input cost per 1K tokens in USD
  - `:optimize_for` - `:cost` | `:latency` | `:quality` (defaults to `:quality`)
  """
  @spec select(map()) :: {:ok, selection()} | {:error, atom()}
  def select(opts \\ %{}) when is_map(opts) do
    providers =
      ProviderRegistry.list_providers()
      |> Enum.reject(&(&1.status == :unhealthy))

    explicit_provider = Map.get(opts, :provider)
    explicit_model = Map.get(opts, :model)
    required_caps = Map.get(opts, :required_capabilities, [])
    max_cost = Map.get(opts, :max_cost_per_1k)
    complexity = Map.get(opts, :complexity, :medium)
    optimize_for = Map.get(opts, :optimize_for, :quality)

    candidates =
      for provider <- providers,
          is_nil(explicit_provider) or provider.id == explicit_provider,
          {model_name, model_meta} <- provider.models,
          is_nil(explicit_model) or model_name == explicit_model,
          capabilities_satisfied?(model_meta, provider, required_caps),
          cost_satisfied?(model_meta, max_cost) do
        %{
          provider_id: provider.id,
          module: provider.module,
          model: model_name,
          metadata: model_meta,
          provider_priority: provider.priority,
          provider_status: provider.status,
          score: score_candidate(provider, model_meta, complexity, optimize_for)
        }
      end

    case Enum.sort_by(candidates, &{-&1.score, &1.provider_priority}) do
      [best | _] ->
        {:ok, Map.take(best, [:provider_id, :module, :model, :metadata])}

      [] ->
        {:error, :no_matching_model}
    end
  end

  defp capabilities_satisfied?(model_meta, provider, required_caps) do
    available = Map.get(model_meta, :capabilities, Map.get(provider, :capabilities, []))
    Enum.all?(required_caps, &(&1 in available))
  end

  defp cost_satisfied?(_model_meta, nil), do: true

  defp cost_satisfied?(model_meta, max_cost) when is_number(max_cost) do
    Map.get(model_meta, :input_cost_per_1k, 0.0) <= max_cost
  end

  defp score_candidate(provider, model_meta, complexity, optimize_for) do
    health_bonus = if provider.status == :healthy, do: 50.0, else: 10.0

    tier_match =
      case {complexity, Map.get(model_meta, :tier, :medium)} do
        {same, same} -> 30.0
        {:high, :medium} -> 15.0
        {:medium, :high} -> 20.0
        {:low, :medium} -> 15.0
        _ -> 5.0
      end

    optimization_bonus =
      case optimize_for do
        :cost ->
          cost = Map.get(model_meta, :input_cost_per_1k, 0.01)
          max(0.0, 25.0 - cost * 1_000.0)

        :latency ->
          if Map.get(model_meta, :latency_class) == :fastest, do: 25.0, else: 5.0

        _quality ->
          case Map.get(model_meta, :tier) do
            :high -> 25.0
            :medium -> 15.0
            _ -> 8.0
          end
      end

    health_bonus + tier_match + optimization_bonus
  end
end
