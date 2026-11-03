defmodule Lux.Beams.Llm.LlmInferenceBeam do
  @moduledoc """
  A coordinated workflow beam for LLM provider abstraction and optimized inference:
  1. Optimizes prompt text and computes cache keys via PromptOptimizerPrism
  2. Selects the best model and provider via ModelSelectorPrism
  3. Pre-computes estimated inference cost via CostTrackerPrism
  """

  use Lux.Beam,
    name: "LLM Inference Orchestration Beam",
    description: "Optimizes prompts, selects best model by strategy, and calculates token costs",
    input_schema: %{
      type: :object,
      properties: %{
        user_prompt: %{type: :string, description: "Input user prompt text"},
        system_prompt: %{type: :string, default: ""},
        strategy: %{type: :string, default: "cost_optimized"}
      },
      required: ["user_prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        optimization_metrics: %{type: :object},
        selected_model: %{type: :object},
        cost_metrics: %{type: :object}
      },
      required: ["status"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Llm.PromptOptimizerPrism
  alias Lux.Prisms.Llm.ModelSelectorPrism
  alias Lux.Prisms.Llm.CostTrackerPrism

  sequence do
    step(:prompt_optimization, PromptOptimizerPrism, %{
      user_prompt: [:input, :user_prompt],
      system_prompt: [:input, :system_prompt]
    })

    step(:model_selection, ModelSelectorPrism, %{
      strategy: [:input, :strategy]
    })

    step(:cost_estimation, CostTrackerPrism, %{
      model: [:steps, :model_selection, :result, :model],
      prompt_tokens: [:steps, :prompt_optimization, :result, :estimated_tokens],
      completion_tokens: 250
    })
  end
end
