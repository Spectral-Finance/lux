defmodule Lux.LLM.ModelSelector do
  @moduledoc """
  Automatic model selection logic for LLM requests.

  The ModelSelector chooses the optimal provider and model based on:

  - **Required capabilities** — e.g., `:tool_use`, `:vision`, `:json_mode`
  - **Cost constraints** — prefer cheaper models when possible
  - **Performance requirements** — prefer low-latency providers
  - **Provider health** — avoid providers with high error rates

  ## Strategies

  - `:best_available` — Pick the highest quality available model (default)
  - `:cheapest` — Minimize cost
  - `:fastest` — Minimize latency based on health data
  - `:balanced` — Balance cost and quality

  ## Usage

      # Select based on requirements
      {:ok, provider, module, model} = Lux.LLM.ModelSelector.select(
        capabilities: [:chat, :tool_use],
        strategy: :cheapest,
        max_cost_per_1k_tokens: 0.01
      )
  """

  alias Lux.LLM.Provider.{Info, ModelInfo}
  alias Lux.LLM.Registry

  @type strategy :: :best_available | :cheapest | :fastest | :balanced
  @type requirement :: [
          {:capabilities, [ModelInfo.capability()]}
          | {:strategy, strategy()}
          | {:max_cost_per_1k_tokens, float()}
          | {:min_context_window, non_neg_integer()}
          | {:preferred_providers, [atom()]}
          | {:excluded_providers, [atom()]}
        ]

  @doc """
  Selects the best provider and model for the given requirements.

  Returns `{:ok, provider_name, provider_module, model_name}` or `{:error, reason}`.

  ## Options

  - `:capabilities` - Required model capabilities (default: `[:chat]`)
  - `:strategy` - Selection strategy (default: `:best_available`)
  - `:max_cost_per_1k_tokens` - Maximum cost constraint
  - `:min_context_window` - Minimum context window size
  - `:preferred_providers` - Preferred provider names (tried first)
  - `:excluded_providers` - Provider names to skip
  """
  @spec select(requirement()) ::
          {:ok, atom(), module(), String.t()} | {:error, String.t()}
  def select(requirements \\ []) do
    capabilities = Keyword.get(requirements, :capabilities, [:chat])
    strategy = Keyword.get(requirements, :strategy, :best_available)
    max_cost = Keyword.get(requirements, :max_cost_per_1k_tokens)
    min_context = Keyword.get(requirements, :min_context_window, 0)
    preferred = Keyword.get(requirements, :preferred_providers, [])
    excluded = Keyword.get(requirements, :excluded_providers, [])

    candidates =
      Registry.list()
      |> Enum.reject(fn {name, _mod, _prio} -> name in excluded end)
      |> Enum.flat_map(fn {name, module, _priority} ->
        case get_provider_models(name, module) do
          {:ok, info} ->
            info.models
            |> filter_by_capabilities(capabilities)
            |> filter_by_context_window(min_context)
            |> filter_by_cost(max_cost)
            |> Enum.map(fn model ->
              %{
                provider_name: name,
                provider_module: module,
                model: model,
                health_score: Registry.health_score(name),
                preferred: name in preferred
              }
            end)

          :error ->
            []
        end
      end)

    case sort_candidates(candidates, strategy) do
      [best | _] ->
        {:ok, best.provider_name, best.provider_module, best.model.name}

      [] ->
        {:error, "No provider/model found matching requirements: #{inspect(requirements)}"}
    end
  end

  @doc """
  Returns all available models across all providers, optionally filtered.
  """
  @spec available_models(keyword()) :: [
          %{provider: atom(), model: ModelInfo.t()}
        ]
  def available_models(opts \\ []) do
    capabilities = Keyword.get(opts, :capabilities, [])

    Registry.list()
    |> Enum.flat_map(fn {name, module, _prio} ->
      case get_provider_models(name, module) do
        {:ok, info} ->
          models =
            if capabilities == [] do
              info.models
            else
              filter_by_capabilities(info.models, capabilities)
            end

          Enum.map(models, fn m -> %{provider: name, model: m} end)

        :error ->
          []
      end
    end)
  end

  # ── Private ─────────────────────────────────────────────────────────

  defp get_provider_models(name, module) do
    if function_exported?(module, :provider_info, 0) do
      {:ok, module.provider_info()}
    else
      {:ok,
       %Info{
         name: name,
         display_name: to_string(name),
         module: module,
         models: []
       }}
    end
  end

  defp filter_by_capabilities(models, required) do
    Enum.filter(models, fn model ->
      Enum.all?(required, fn cap -> cap in model.capabilities end)
    end)
  end

  defp filter_by_context_window(models, min_context) do
    Enum.filter(models, fn model -> model.context_window >= min_context end)
  end

  defp filter_by_cost(models, nil), do: models

  defp filter_by_cost(models, max_cost) do
    Enum.filter(models, fn model ->
      avg_cost = (model.cost_per_input_token + model.cost_per_output_token) / 2.0
      avg_cost * 1000 <= max_cost
    end)
  end

  defp sort_candidates(candidates, :cheapest) do
    Enum.sort_by(candidates, fn c ->
      avg = (c.model.cost_per_input_token + c.model.cost_per_output_token) / 2.0
      # Prefer lower cost, break ties with health
      {avg, -c.health_score}
    end)
  end

  defp sort_candidates(candidates, :fastest) do
    Enum.sort_by(candidates, fn c ->
      # Higher health score = likely faster; prefer those
      {-c.health_score, c.model.cost_per_input_token}
    end)
  end

  defp sort_candidates(candidates, :balanced) do
    Enum.sort_by(candidates, fn c ->
      cost = (c.model.cost_per_input_token + c.model.cost_per_output_token) / 2.0
      # Composite: health (40%), inverse cost (30%), context (30%)
      score =
        c.health_score * 0.4 +
          max(0.0, 1.0 - cost * 100_000) * 0.3 +
          min(1.0, c.model.context_window / 128_000) * 0.3

      preferred_bonus = if c.preferred, do: 1.0, else: 0.0
      -(score + preferred_bonus)
    end)
  end

  defp sort_candidates(candidates, :best_available) do
    Enum.sort_by(candidates, fn c ->
      # Higher context window + more capabilities = better quality
      quality =
        length(c.model.capabilities) * 0.3 +
          min(1.0, c.model.context_window / 200_000) * 0.4 +
          c.health_score * 0.3

      preferred_bonus = if c.preferred, do: 1.0, else: 0.0
      -(quality + preferred_bonus)
    end)
  end
end
