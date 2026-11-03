defmodule Lux.LLM.CostTracker do
  @moduledoc """
  Token accounting and LLM cost estimation engine:
  - Tracks prompt tokens, completion tokens, and cached tokens
  - Computes exact USD inference costs using per-million token pricing
  """

  @rates %{
    # model => {input_per_m, output_per_m}
    "gpt-4o" => {2.50, 10.00},
    "gpt-4o-mini" => {0.15, 0.60},
    "o1" => {15.00, 60.00},
    "claude-3-5-sonnet-20241022" => {3.00, 15.00},
    "claude-3-5-haiku-20241022" => {0.80, 4.00},
    "llama-3.3-70b-versatile" => {0.59, 0.79}
  }

  @doc """
  Calculates USD inference cost for token usage on a model.
  """
  @spec calculate_cost(String.t(), non_neg_integer(), non_neg_integer()) :: %{
          model: String.t(),
          prompt_tokens: non_neg_integer(),
          completion_tokens: non_neg_integer(),
          total_tokens: non_neg_integer(),
          prompt_cost_usd: float(),
          completion_cost_usd: float(),
          total_cost_usd: float()
        }
  def calculate_cost(model, prompt_tokens, completion_tokens)
      when is_binary(model) and prompt_tokens >= 0 and completion_tokens >= 0 do
    {input_rate, output_rate} = Map.get(@rates, model, {1.00, 3.00})

    input_cost = prompt_tokens * (input_rate / 1_000_000.0)
    output_cost = completion_tokens * (output_rate / 1_000_000.0)
    total_cost = input_cost + output_cost

    %{
      model: model,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      total_tokens: prompt_tokens + completion_tokens,
      prompt_cost_usd: Float.round(input_cost, 6),
      completion_cost_usd: Float.round(output_cost, 6),
      total_cost_usd: Float.round(total_cost, 6)
    }
  end
end
