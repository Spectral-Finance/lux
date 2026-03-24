defmodule Lux.LLM.ModelSelector do
  @moduledoc """
  Intelligent model selection for LLM providers.

  Selects the best model based on:
  - Cost optimization
  - Latency requirements
  - Quality requirements
  - Feature requirements
  - Token limits

  ## Selection Strategies

  - `:cost` - Minimize cost per token
  - `:speed` - Minimize latency
  - `:quality` - Maximize output quality
  - `:balanced` - Balance between cost, speed, and quality

  ## Usage

      # Select cheapest model
      {provider, model} = ModelSelector.select_best(%{priority: :cost})

      # Select fastest model
      {provider, model} = ModelSelector.select_best(%{priority: :speed})

      # Select model with specific features
      {provider, model} = ModelSelector.select_best(%{
        priority: :quality,
        features: [:vision, :tools]
      })

  """

  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.PerformanceMonitor

  @type priority :: :cost | :speed | :quality | :balanced
  @type selection_result :: {atom(), String.t()} | {:error, term()}

  @doc """
  Select the best provider and model for a given task.

  ## Options

    * `:priority` - Selection priority (default: :balanced)
    * `:max_tokens` - Maximum tokens required
    * `:features` - Required features (e.g., [:vision, :tools])
    * `:exclude` - Providers to exclude
    * `:prefer` - Preferred providers

  ## Examples

      iex> ModelSelector.select_best(%{priority: :cost})
      {:together_ai, "mistralai/Mixtral-8x7B-Instruct-v0.1"}

      iex> ModelSelector.select_best(%{priority: :quality, features: [:vision]})
      {:openai, "gpt-4-turbo"}

  """
  @spec select_best(map()) :: selection_result()
  def select_best(opts \\ %{}) do
    opts = Map.merge(default_opts(), opts)

    candidates = get_candidates(opts)

    if Enum.empty?(candidates) do
      {:error, :no_matching_providers}
    else
      rank_and_select(candidates, opts)
    end
  end

  @doc """
  Build a fallback chain of providers.

  ## Examples

      iex> ModelSelector.build_chain(%{priority: :cost})
      [{:together_ai, "mistralai/Mixtral-8x7B-Instruct-v0.1"}, ...]

  """
  @spec build_chain(map()) :: [{atom(), String.t()}]
  def build_chain(opts \\ %{}) do
    opts = Map.merge(default_opts(), opts)
    candidates = get_candidates(opts)

    candidates
    |> Enum.map(fn {provider, model, _score} -> {provider, model} end)
    |> Enum.take(5)
  end

  @doc """
  Get the cost for a specific provider and model.

  ## Examples

      iex> ModelSelector.get_cost(:openai, "gpt-4", 1000, 500)
      0.06

  """
  @spec get_cost(atom(), String.t(), non_neg_integer(), non_neg_integer()) :: float()
  def get_cost(provider, model, input_tokens, output_tokens) do
    config = ProviderRegistry.get_config(provider)

    case get_in(config, [:cost_per_1k_tokens, model]) do
      nil -> 0.0
      costs ->
        input_cost = Map.get(costs, :input, 0) * (input_tokens / 1000)
        output_cost = Map.get(costs, :output, 0) * (output_tokens / 1000)
        input_cost + output_cost
    end
  end

  # Private functions

  defp default_opts do
    %{priority: :balanced, features: [], exclude: [], prefer: []}
  end

  defp get_candidates(opts) do
    ProviderRegistry.list_enabled()
    |> Enum.reject(fn provider -> provider in Map.get(opts, :exclude, []) end)
    |> Enum.flat_map(fn provider ->
      config = ProviderRegistry.get_config(provider)
      models = Map.get(config, :models, [])

      models
      |> Enum.filter(fn model -> model_matches_requirements?(provider, model, opts) end)
      |> Enum.map(fn model ->
        score = calculate_score(provider, model, config, opts)
        {provider, model, score}
      end)
    end)
    |> Enum.sort_by(fn {_p, _m, score} -> score end, :desc)
  end

  defp model_matches_requirements?(provider, model, opts) do
    config = ProviderRegistry.get_config(provider)
    model_config = get_model_config(config, model)

    # Check max tokens requirement
    max_tokens_ok = case Map.get(opts, :max_tokens) do
      nil -> true
      required ->
        Map.get(model_config, :max_tokens, config[:max_tokens] || 0) >= required
    end

    # Check features requirement
    features_ok = case Map.get(opts, :features, []) do
      [] -> true
      required_features ->
        available_features = Map.get(config, :features, [])
        Enum.all?(required_features, fn f -> f in available_features end)
    end

    max_tokens_ok and features_ok
  end

  defp get_model_config(config, model) do
    # Model-specific config if available
    Map.get(config, :models_config, %{})
    |> Map.get(model, %{})
  end

  defp calculate_score(provider, model, config, opts) do
    priority = Map.get(opts, :priority, :balanced)
    prefer = Map.get(opts, :prefer, [])

    base_score = calculate_base_score(priority, provider, model, config)
    preference_bonus = if provider in prefer, do: 0.2, else: 0.0

    # Get performance data for latency scoring
    stats = PerformanceMonitor.get_stats(provider)
    latency_score = calculate_latency_score(stats)

    case priority do
      :cost -> base_score * 0.8 + latency_score * 0.2 + preference_bonus
      :speed -> base_score * 0.3 + latency_score * 0.7 + preference_bonus
      :quality -> base_score * 0.9 + latency_score * 0.1 + preference_bonus
      :balanced -> base_score * 0.5 + latency_score * 0.5 + preference_bonus
    end
  end

  defp calculate_base_score(:cost, provider, model, config) do
    costs = get_in(config, [:cost_per_1k_tokens, model]) || %{input: 0.01, output: 0.01}
    total_cost = costs[:input] + costs[:output]

    # Lower cost = higher score
    1.0 / (total_cost + 0.001)
  end

  defp calculate_base_score(:speed, _provider, _model, _config) do
    # Speed is calculated from actual performance data
    0.5
  end

  defp calculate_base_score(:quality, provider, model, _config) do
    # Quality ranking based on model family
    quality_scores = %{
      {"openai", "gpt-4"} => 0.95,
      {"openai", "gpt-4-turbo"} => 0.92,
      {"anthropic", "claude-3-opus-20240229"} => 0.96,
      {"anthropic", "claude-3-sonnet-20240229"} => 0.85,
      {"anthropic", "claude-3-haiku-20240307"} => 0.75,
      {"openai", "gpt-3.5-turbo"} => 0.70
    }

    Map.get(quality_scores, {Atom.to_string(provider), model}, 0.5)
  end

  defp calculate_base_score(:balanced, provider, model, config) do
    quality = calculate_base_score(:quality, provider, model, config)
    cost = calculate_base_score(:cost, provider, model, config)

    (quality + cost) / 2
  end

  defp calculate_latency_score(stats) do
    case Map.get(stats, :avg_latency_ms) do
      nil -> 0.5
      latency ->
        # Lower latency = higher score
        # Normalize: 100ms = 1.0, 5000ms = 0.1
        max(0.1, 1.0 - (latency / 5000))
    end
  end

  defp rank_and_select(candidates, _opts) do
    case candidates do
      [{provider, model, _score} | _] -> {provider, model}
      [] -> {:error, :no_candidates}
    end
  end
end