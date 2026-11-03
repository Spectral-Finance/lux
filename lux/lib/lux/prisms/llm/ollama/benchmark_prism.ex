defmodule Lux.Prisms.Llm.Ollama.BenchmarkPrism do
  @moduledoc """
  A prism that benchmarks token generation throughput (eval tokens/sec) and prompt
  processing speed on the local hardware for a specific model.
  """

  use Lux.Prism,
    name: "Ollama Benchmark",
    description: "Evaluates inference latency, prompt processing rate, and tokens/sec",
    input_schema: %{
      type: :object,
      properties: %{
        model: %{
          type: :string,
          description: "Model to benchmark",
          default: "llama3.2"
        },
        prompt: %{
          type: :string,
          description: "Benchmark prompt to evaluate",
          default: "Count from 1 to 20 separated by commas."
        },
        num_predict: %{
          type: :integer,
          description: "Max tokens to generate during benchmark",
          default: 100
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        model: %{type: :string},
        eval_tokens_per_sec: %{type: :number},
        prompt_tokens_per_sec: %{type: :number},
        total_duration_ms: %{type: :number},
        tokens_generated: %{type: :integer}
      },
      required: ["model", "eval_tokens_per_sec", "total_duration_ms"]
    }

  alias Lux.LLM.Ollama

  @impl true
  def handler(inputs, _context) do
    model = Map.get(inputs, "model") || Map.get(inputs, :model, "llama3.2")
    prompt = Map.get(inputs, "prompt") || Map.get(inputs, :prompt, "Count from 1 to 20 separated by commas.")
    num_predict = Map.get(inputs, "num_predict") || Map.get(inputs, :num_predict, 100)

    config = %{
      model: model,
      temperature: 0.0,
      num_predict: num_predict
    }

    case Ollama.call(prompt, [], config) do
      {:ok, %Lux.Signal{metadata: metadata}} ->
        metrics = metadata[:metrics] || %{}

        prompt_tps = Map.get(metrics, :prompt_tokens_per_sec, 0.0)
        eval_tps = Map.get(metrics, :eval_tokens_per_sec, 0.0)
        total_duration_ms = Map.get(metrics, :total_duration_ms, 0.0)
        eval_tokens = Map.get(metrics, :eval_tokens, 0)

        {:ok,
         %{
           model: model,
           eval_tokens_per_sec: eval_tps,
           prompt_tokens_per_sec: prompt_tps,
           total_duration_ms: total_duration_ms,
           tokens_generated: eval_tokens
         }}

      {:error, reason} ->
        {:error, "Ollama BenchmarkPrism failed: #{inspect(reason)}"}
    end
  end
end
