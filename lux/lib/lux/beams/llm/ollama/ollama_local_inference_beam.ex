defmodule Lux.Beams.Llm.Ollama.OllamaLocalInferenceBeam do
  @moduledoc """
  A beam that manages local LLM inference lifecycle on Ollama:
  1. Checks model availability.
  2. Pre-warms the model in memory/VRAM to eliminate first-token cold start latency.
  3. Executes the prompt with fine-grained context and hardware configurations.
  4. Records hardware resource telemetry and token generation throughput.

  ## Example Usage

  ```elixir
  {:ok, result, execution_log} = Lux.Beams.Llm.Ollama.OllamaLocalInferenceBeam.run(%{
    prompt: "Summarize this transaction log",
    model: "llama3.2",
    temperature: 0.2
  })
  ```
  """

  use Lux.Beam,
    name: "Ollama Local Inference Pipeline",
    description: "Orchestrates model verification, pre-warming, inference, and resource telemetry on Ollama",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "Prompt to execute locally"
        },
        model: %{
          type: :string,
          description: "Model identifier (e.g. 'llama3.2', 'deepseek-r1:7b')",
          default: "llama3.2"
        },
        temperature: %{
          type: :number,
          default: 0.7
        },
        num_ctx: %{
          type: :integer,
          default: 4096
        },
        keep_alive: %{
          type: :string,
          default: "10m"
        }
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content: %{type: [:string, :object]},
        model: %{type: :string},
        metrics: %{type: :object},
        vram_mb: %{type: :number}
      },
      required: ["content", "model"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Llm.Ollama.ChatPrism
  alias Lux.Prisms.Llm.Ollama.ModelCachePrism
  alias Lux.Prisms.Llm.Ollama.ModelManagePrism
  alias Lux.Prisms.Llm.Ollama.ResourceMonitorPrism

  sequence do
    # Step 1: Verify model presence
    step(:model_check, ModelManagePrism, %{
      action: "check",
      model_name: [:input, :model]
    })

    # Step 2: Pre-warm model in memory to eliminate cold start
    step(:pre_warm, ModelCachePrism, %{
      action: "preload",
      model_name: [:input, :model],
      keep_alive: [:input, :keep_alive]
    })

    # Step 3: Run inference
    step(:inference, ChatPrism, %{
      prompt: [:input, :prompt],
      model: [:input, :model],
      temperature: [:input, :temperature],
      num_ctx: [:input, :num_ctx]
    })

    # Step 4: Monitor resource state
    step(:telemetry, ResourceMonitorPrism, %{})
  end
end
