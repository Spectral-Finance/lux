defmodule Lux.LLM.Perplexity.ModelRouter do
  @moduledoc """
  Model selection and pricing calculation for Perplexity AI models.

  Models include:
  - `sonar`: Lightweight search model for fast answers
  - `sonar-pro`: Premier search model for comprehensive analysis
  - `sonar-reasoning`: Search model with multi-step reasoning capabilities
  - `sonar-reasoning-pro`: Flagship reasoning model for complex questions
  """

  @models %{
    "sonar" => %{
      name: "Sonar",
      type: :fast,
      context_length: 128_000,
      pricing: %{prompt: 1.0, completion: 1.0, search_per_1k: 5.0} # $1/1M prompt, $1/1M completion, $5/1000 searches
    },
    "sonar-pro" => %{
      name: "Sonar Pro",
      type: :pro,
      context_length: 200_000,
      pricing: %{prompt: 3.0, completion: 15.0, search_per_1k: 5.0}
    },
    "sonar-reasoning" => %{
      name: "Sonar Reasoning",
      type: :reasoning,
      context_length: 128_000,
      pricing: %{prompt: 1.0, completion: 5.0, search_per_1k: 5.0}
    },
    "sonar-reasoning-pro" => %{
      name: "Sonar Reasoning Pro",
      type: :reasoning_pro,
      context_length: 128_000,
      pricing: %{prompt: 2.0, completion: 8.0, search_per_1k: 5.0}
    }
  }

  @doc """
  Returns all available Perplexity models.
  """
  def catalog, do: @models

  @doc """
  Selects a model based on requested strategy.
  Strategies: `:reasoning`, `:reasoning_pro`, `:pro`, `:fast`, `:default`
  """
  @spec select_model(atom() | String.t()) :: String.t()
  def select_model(:reasoning_pro), do: "sonar-reasoning-pro"
  def select_model("reasoning_pro"), do: "sonar-reasoning-pro"
  def select_model(:reasoning), do: "sonar-reasoning"
  def select_model("reasoning"), do: "sonar-reasoning"
  def select_model(:pro), do: "sonar-pro"
  def select_model("pro"), do: "sonar-pro"
  def select_model(:fast), do: "sonar"
  def select_model("fast"), do: "sonar"
  def select_model(_), do: "sonar-pro"

  @doc """
  Calculates USD cost based on tokens and search queries.
  """
  @spec estimate_cost(String.t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: map()
  def estimate_cost(model_name, prompt_tokens, completion_tokens, search_queries \\ 1) do
    model_meta = Map.get(@models, model_name, %{pricing: %{prompt: 1.0, completion: 1.0, search_per_1k: 5.0}})
    pricing = model_meta.pricing

    prompt_cost = (prompt_tokens / 1_000_000.0) * pricing.prompt
    completion_cost = (completion_tokens / 1_000_000.0) * pricing.completion
    search_cost = (search_queries / 1_000.0) * pricing.search_per_1k
    total_cost = Float.round(prompt_cost + completion_cost + search_cost, 6)

    %{
      model: model_name,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      search_queries: search_queries,
      prompt_cost: Float.round(prompt_cost, 6),
      completion_cost: Float.round(completion_cost, 6),
      search_cost: Float.round(search_cost, 6),
      total_cost: total_cost
    }
  end
end
