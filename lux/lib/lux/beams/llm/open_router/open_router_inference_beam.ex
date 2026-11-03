defmodule Lux.Beams.Llm.OpenRouter.OpenRouterInferenceBeam do
  @moduledoc """
  A beam orchestrating end-to-end OpenRouter LLM inference with:
  1. Automated model routing based on constraints and strategy.
  2. Resilient multi-model fallback execution.
  3. Real-time cost accounting, token metrics, and budget tracking.

  ## Example Usage

  ```elixir
  {:ok, result, execution_log} = Lux.Beams.Llm.OpenRouter.OpenRouterInferenceBeam.run(%{
    prompt: "Explain zero-knowledge rollups in 3 paragraphs",
    strategy: "smartest",
    budget_limit: 0.05
  })
  ```
  """

  use Lux.Beam,
    name: "OpenRouter Inference Pipeline",
    description: "Orchestrates routing, resilient completion, and cost calculation via OpenRouter",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "Prompt to generate completion for"
        },
        strategy: %{
          type: :string,
          description: "Selection strategy (smartest, balanced, fastest, cheapest, free)",
          default: "balanced"
        },
        min_context: %{
          type: :integer,
          description: "Minimum context window required",
          default: 0
        },
        temperature: %{
          type: :number,
          description: "Sampling temperature",
          default: 0.7
        },
        budget_limit: %{
          type: :number,
          description: "Optional maximum USD budget limit"
        },
        api_key: %{
          type: :string,
          description: "Optional API key override"
        }
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content: %{type: [:string, :object]},
        model_used: %{type: :string},
        total_cost: %{type: :number},
        budget_exceeded: %{type: :boolean},
        attempts: %{type: :integer}
      },
      required: ["content", "model_used", "total_cost"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Llm.OpenRouter.CostPrism
  alias Lux.Prisms.Llm.OpenRouter.FallbackPrism
  alias Lux.Prisms.Llm.OpenRouter.ModelRoutePrism

  sequence do
    # Step 1: Select optimal model and fallback chain
    step(:model_selection, ModelRoutePrism, %{
      strategy: [:input, :strategy],
      min_context: [:input, :min_context]
    })

    # Step 2: Execute inference with resilient fallback cascade
    step(:inference, FallbackPrism, %{
      prompt: [:input, :prompt],
      models: [:steps, :model_selection, :fallback_chain],
      temperature: [:input, :temperature],
      api_key: [:input, :api_key]
    })

    # Step 3: Calculate token costs and check budget
    step(:cost_accounting, CostPrism, %{
      model: [:steps, :inference, :model_used],
      prompt_tokens: [:steps, :inference, :usage, "prompt_tokens"],
      completion_tokens: [:steps, :inference, :usage, "completion_tokens"],
      budget_limit: [:input, :budget_limit]
    })
  end
end
