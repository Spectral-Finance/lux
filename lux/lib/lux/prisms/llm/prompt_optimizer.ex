defmodule Lux.Prisms.Llm.PromptOptimizerPrism do
  @moduledoc """
  Optimizes prompts, calculates token estimates, and produces deterministic cache keys.
  """

  use Lux.Prism,
    name: "LLM Prompt Optimizer",
    description: "Minifies prompt text, estimates tokens, and generates deterministic prompt cache key",
    input_schema: %{
      type: :object,
      properties: %{
        system_prompt: %{type: :string, default: ""},
        user_prompt: %{type: :string}
      },
      required: ["user_prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        optimized_user_prompt: %{type: :string},
        estimated_tokens: %{type: :integer},
        cache_key: %{type: :string}
      },
      required: ["optimized_user_prompt", "estimated_tokens", "cache_key"]
    }

  alias Lux.LLM.Optimizer

  def handler(input, _ctx) do
    system_prompt = Map.get(input, :system_prompt) || Map.get(input, "system_prompt", "")
    user_prompt = Map.get(input, :user_prompt) || Map.get(input, "user_prompt", "")

    optimized = Optimizer.optimize_prompt(user_prompt)
    key = Optimizer.cache_key(system_prompt, user_prompt)
    tokens = Optimizer.estimate_tokens(optimized)

    {:ok,
     %{
       optimized_user_prompt: optimized,
       estimated_tokens: tokens,
       cache_key: key
     }}
  end
end
