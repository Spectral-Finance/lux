defmodule Lux.LLM.CostTracker do
  @moduledoc """
  Tracks token consumption, calculates USD costs across providers and models,
  and monitors agent operational spending against configured budgets.
  """

  # Pricing per 1,000,000 tokens (Input / Output in USD)
  @model_rates %{
    # OpenAI
    "gpt-4o" => %{input: 2.50, output: 10.00},
    "gpt-4o-mini" => %{input: 0.15, output: 0.60},
    "o1" => %{input: 15.00, output: 60.00},
    "o3-mini" => %{input: 1.10, output: 4.40},

    # Anthropic
    "claude-3-5-sonnet-20241022" => %{input: 3.00, output: 15.00},
    "claude-3-5-haiku-20241022" => %{input: 0.80, output: 4.00},
    "claude-3-opus-20240229" => %{input: 15.00, output: 75.00},

    # Perplexity
    "sonar-pro" => %{input: 3.00, output: 15.00},
    "sonar" => %{input: 1.00, output: 1.00},

    # Together AI / OpenRouter
    "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo" => %{input: 0.88, output: 0.88},
    "meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo" => %{input: 0.18, output: 0.18},

    # Local / Ollama
    "ollama" => %{input: 0.0, output: 0.0}
  }

  @doc """
  Calculates the cost in USD for given prompt and completion tokens.
  """
  @spec calculate_cost(integer(), integer(), String.t()) :: float()
  def calculate_cost(prompt_tokens, completion_tokens, model) do
    rates = Map.get(@model_rates, model, %{input: 1.00, output: 3.00})

    input_cost = prompt_tokens / 1_000_000 * rates.input
    output_cost = completion_tokens / 1_000_000 * rates.output

    Float.round(input_cost + output_cost, 6)
  end

  @doc """
  Records usage event into process or runtime state.
  """
  @spec record_usage(atom() | String.t(), String.t(), integer(), integer(), map()) :: map()
  def record_usage(provider, model, prompt_tokens, completion_tokens, meta \\ %{}) do
    cost = calculate_cost(prompt_tokens, completion_tokens, model)

    event = %{
      provider: to_string(provider),
      model: model,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      total_tokens: prompt_tokens + completion_tokens,
      cost_usd: cost,
      metadata: meta,
      timestamp: System.system_time(:millisecond)
    }

    history = Process.get(:lux_llm_cost_history, [])
    Process.put(:lux_llm_cost_history, [event | history])

    event
  end

  @doc """
  Summarizes total LLM expenditure and token usage recorded so far.
  """
  @spec get_summary() :: map()
  def get_summary do
    history = Process.get(:lux_llm_cost_history, [])

    Enum.reduce(
      history,
      %{
        total_requests: 0,
        total_tokens: 0,
        total_cost_usd: 0.0,
        by_provider: %{},
        by_model: %{}
      },
      fn item, acc ->
        prov = item.provider
        model = item.model

        prov_cost = Map.get(acc.by_provider, prov, 0.0) + item.cost_usd
        model_cost = Map.get(acc.by_model, model, 0.0) + item.cost_usd

        %{
          total_requests: acc.total_requests + 1,
          total_tokens: acc.total_tokens + item.total_tokens,
          total_cost_usd: Float.round(acc.total_cost_usd + item.cost_usd, 6),
          by_provider: Map.put(acc.by_provider, prov, Float.round(prov_cost, 6)),
          by_model: Map.put(acc.by_model, model, Float.round(model_cost, 6))
        }
      end
    )
  end

  @doc """
  Checks if spending exceeds a specified budget limit.
  """
  @spec check_budget_limit(float()) :: {:ok, :within_budget, float()} | {:exceeded, float(), float()}
  def check_budget_limit(budget_usd) do
    summary = get_summary()
    current_spend = summary.total_cost_usd

    if current_spend <= budget_usd do
      {:ok, :within_budget, current_spend}
    else
      {:exceeded, current_spend, budget_usd}
    end
  end

  @doc """
  Resets recorded usage history.
  """
  @spec reset!() :: :ok
  def reset! do
    Process.put(:lux_llm_cost_history, [])
    :ok
  end
end
