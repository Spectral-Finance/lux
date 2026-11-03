defmodule Lux.Prisms.Llm.Ollama.ChatPrism do
  @moduledoc """
  A prism for running inference against local Ollama models with hardware tuning
  and performance telemetry capture.
  """

  use Lux.Prism,
    name: "Ollama Local Chat Completion",
    description: "Executes chat completion with local Ollama models and measures performance",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "Prompt to send to local model"
        },
        model: %{
          type: :string,
          description: "Local model name (e.g. 'llama3.2', 'mistral', 'qwen2.5:7b')",
          default: "llama3.2"
        },
        temperature: %{
          type: :number,
          default: 0.7
        },
        num_ctx: %{
          type: :integer,
          description: "Context window size in tokens",
          default: 4096
        },
        num_gpu: %{
          type: :integer,
          description: "Number of GPU layers to offload"
        },
        keep_alive: %{
          type: [:string, :integer],
          description: "Duration to keep model in memory (e.g. '10m', -1)",
          default: "5m"
        }
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content: %{type: [:string, :object]},
        model: %{type: :string},
        finish_reason: %{type: :string},
        metrics: %{type: :object}
      },
      required: ["content", "model"]
    }

  alias Lux.LLM.Ollama

  @impl true
  def handler(inputs, _context) do
    prompt = Map.get(inputs, "prompt") || Map.get(inputs, :prompt)
    model = Map.get(inputs, "model") || Map.get(inputs, :model, "llama3.2")
    temperature = Map.get(inputs, "temperature") || Map.get(inputs, :temperature, 0.7)
    num_ctx = Map.get(inputs, "num_ctx") || Map.get(inputs, :num_ctx, 4096)
    num_gpu = Map.get(inputs, "num_gpu") || Map.get(inputs, :num_gpu)
    keep_alive = Map.get(inputs, "keep_alive") || Map.get(inputs, :keep_alive, "5m")

    config =
      %{
        model: model,
        temperature: temperature,
        num_ctx: num_ctx,
        keep_alive: keep_alive
      }
      |> maybe_put(:num_gpu, num_gpu)

    case Ollama.call(prompt, [], config) do
      {:ok, %Lux.Signal{payload: payload, metadata: metadata}} ->
        metrics = metadata[:metrics] || %{}

        metrics_map =
          case metrics do
            %Lux.LLM.Ollama.ResourceMonitor.Metrics{} = m -> Map.from_struct(m)
            m when is_map(m) -> m
            _ -> %{}
          end

        {:ok,
         %{
           content: payload.content,
           model: payload.model,
           finish_reason: payload.finish_reason,
           metrics: metrics_map
         }}

      {:error, reason} ->
        {:error, "Ollama ChatPrism error: #{inspect(reason)}"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
