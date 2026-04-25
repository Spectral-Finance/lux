defmodule Lux.LLM.ModelSelector do
  @moduledoc """
  Intelligent model selection based on task type, cost constraints,
  latency requirements, and provider availability.

  ## Selection Strategies

  - `:cheapest` — Select the lowest-cost model that meets requirements
  - `:fastest` — Select the model with lowest average latency
  - `:smartest` — Select the highest-capability model available
  - `:balanced` — Balance cost, speed, and capability (default)

  ## Usage

      # Auto-select based on strategy
      Lux.LLM.ModelSelector.select("Explain quantum computing",
        strategy: :balanced,
        cost_limit: 0.05)

      # Get ranked list of models
      Lux.LLM.ModelSelector.rank_models("Write a poem",
        strategy: :cheapest)
  """

  alias Lux.LLM.ProviderRegistry

  @strategies [:cheapest, :fastest, :smartest, :balanced]

  @model_capabilities %{
    # OpenAI
    "gpt-4"                => %{capability: 5, speed: 2, cost_tier: 4},
    "gpt-4-turbo"          => %{capability: 5, speed: 3, cost_tier: 3},
    "gpt-4o"               => %{capability: 5, speed: 4, cost_tier: 3},
    "gpt-4o-mini"          => %{capability: 3, speed: 5, cost_tier: 1},
    "gpt-3.5-turbo"        => %{capability: 2, speed: 5, cost_tier: 1},
    # Anthropic
    "claude-3-opus"        => %{capability: 5, speed: 2, cost_tier: 5},
    "claude-3-sonnet"      => %{capability: 4, speed: 4, cost_tier: 3},
    "claude-3-haiku"       => %{capability: 3, speed: 5, cost_tier: 1},
    "claude-3.5-sonnet"    => %{capability: 5, speed: 4, cost_tier: 3},
    # Google
    "gemini-pro"           => %{capability: 4, speed: 4, cost_tier: 2},
    "gemini-ultra"         => %{capability: 5, speed: 3, cost_tier: 4},
    "gemini-1.5-pro"       => %{capability: 5, speed: 3, cost_tier: 3},
    "gemini-1.5-flash"     => %{capability: 3, speed: 5, cost_tier: 1},
    # Ollama (local)
    "llama3"               => %{capability: 3, speed: 3, cost_tier: 0},
    "llama3:70b"           => %{capability: 4, speed: 2, cost_tier: 0},
    "mistral"              => %{capability: 3, speed: 4, cost_tier: 0},
    # OpenRouter
    "openai/gpt-4o-mini"   => %{capability: 3, speed: 5, cost_tier: 1},
    "anthropic/claude-3-haiku" => %{capability: 3, speed: 5, cost_tier: 1},
  }

  @model_costs %{
    "gpt-4"                => %{input: 0.00003, output: 0.00006},
    "gpt-4-turbo"          => %{input: 0.00001, output: 0.00003},
    "gpt-4o"               => %{input: 0.000005, output: 0.000015},
    "gpt-4o-mini"          => %{input: 0.00000015, output: 0.0000006},
    "gpt-3.5-turbo"        => %{input: 0.0000005, output: 0.0000015},
    "claude-3-opus"        => %{input: 0.000015, output: 0.000075},
    "claude-3-sonnet"      => %{input: 0.000003, output: 0.000015},
    "claude-3-haiku"       => %{input: 0.00000025, output: 0.00000125},
    "claude-3.5-sonnet"    => %{input: 0.000003, output: 0.000015},
    "gemini-pro"           => %{input: 0.00000125, output: 0.000005},
    "gemini-ultra"         => %{input: 0.000035, output: 0.000105},
    "gemini-1.5-pro"       => %{input: 0.0000035, output: 0.0000105},
    "gemini-1.5-flash"     => %{input: 0.000000075, output: 0.0000003},
    "llama3"               => %{input: 0.0, output: 0.0},
    "llama3:70b"           => %{input: 0.0, output: 0.0},
    "mistral"              => %{input: 0.0, output: 0.0},
    "openai/gpt-4o-mini"   => %{input: 0.00000015, output: 0.0000006},
    "anthropic/claude-3-haiku" => %{input: 0.00000025, output: 0.00000125},
  }

  @type strategy :: :cheapest | :fastest | :smartest | :balanced
  @type selection :: %{
    model: String.t(),
    provider: atom(),
    estimated_cost: float(),
    score: float()
  }

  @doc """
  Select the best model for a prompt based on the given strategy.
  """
  @spec select(String.t(), keyword()) :: selection() | nil
  def select(prompt, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :balanced)
    cost_limit = Keyword.get(opts, :cost_limit)
    preference = Keyword.get(opts, :preference, [])

    # If user has model preferences, try those first
    if preference != [] do
      case try_preferences(preference, prompt, cost_limit) do
        {:ok, selection} -> selection
        :no_match -> rank_and_select(prompt, strategy, cost_limit)
      end
    else
      rank_and_select(prompt, strategy, cost_limit)
    end
  end

  @doc """
  Rank all available models by the given strategy.
  """
  @spec rank_models(String.t(), keyword()) :: [selection()]
  def rank_models(prompt, opts \\ []) do
    strategy = Keyword.get(opts, :strategy, :balanced)
    cost_limit = Keyword.get(opts, :cost_limit)
    input_tokens = estimate_tokens(prompt)
    output_tokens = Keyword.get(opts, :max_tokens, 1000)

    providers = ProviderRegistry.list_providers()

    available_models =
      for provider <- providers,
          provider.enabled,
          model <- provider.models,
          reduce: [] do
        acc ->
          costs = Map.get(@model_costs, model, %{input: 0.001, output: 0.002})
          est_cost = (input_tokens * costs.input + output_tokens * costs.output)

          if cost_limit && est_cost > cost_limit do
            acc
          else
            caps = Map.get(@model_capabilities, model, %{capability: 3, speed: 3, cost_tier: 2})
            score = compute_score(strategy, caps, est_cost)

            [%{
              model: model,
              provider: provider.id,
              estimated_cost: Float.round(est_cost, 6),
              score: score
            } | acc]
          end
      end

    available_models
    |> Enum.sort_by(& &1.score, :desc)
  end

  # Private

  defp try_preferences(preference, prompt, cost_limit) do
    input_tokens = estimate_tokens(prompt)

    Enum.reduce_while(preference, :no_match, fn model, _acc ->
      costs = Map.get(@model_costs, model, %{input: 0.001, output: 0.002})
      est_cost = (input_tokens * costs.input + 500 * costs.output)

      if cost_limit && est_cost > cost_limit do
        {:cont, :no_match}
      else
        provider = ProviderRegistry.select_for_model(model)
        if provider do
          {:halt, {:ok, %{
            model: model,
            provider: provider.id,
            estimated_cost: Float.round(est_cost, 6),
            score: 1.0
          }}}
        else
          {:cont, :no_match}
        end
      end
    end)
  end

  defp rank_and_select(prompt, strategy, cost_limit) do
    ranked = rank_models(prompt, strategy: strategy, cost_limit: cost_limit)
    List.first(ranked)
  end

  defp compute_score(:cheapest, _caps, cost), do: 1.0 / (cost + 0.0001)
  defp compute_score(:fastest, caps, _cost), do: caps.speed / 5.0
  defp compute_score(:smartest, caps, _cost), do: caps.capability / 5.0
  defp compute_score(:balanced, caps, cost) do
    # Weighted: 40% capability, 30% speed, 30% cost efficiency
    cap_score = caps.capability / 5.0
    speed_score = caps.speed / 5.0
    cost_score = 1.0 / (cost * 1000 + 0.1)
    0.4 * cap_score + 0.3 * speed_score + 0.3 * cost_score
  end

  defp estimate_tokens(text) when is_binary(text) do
    div(String.length(text), 4) + 1
  end

  defp estimate_tokens(_), do: 100
end
