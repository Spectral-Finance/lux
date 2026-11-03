defmodule Lux.Prisms.Llm.Ollama.ModelCachePrism do
  @moduledoc """
  A prism for managing model residency in RAM/VRAM via Ollama's `keep_alive` mechanism:
  - Pre-warming / pre-loading models so subsequent inference has zero initial load latency.
  - Evicting / unloading models to free GPU VRAM when tasks complete.
  """

  use Lux.Prism,
    name: "Ollama Model Cache Control",
    description: "Pre-warms or unloads Ollama models into/from memory using keep_alive",
    input_schema: %{
      type: :object,
      properties: %{
        model_name: %{
          type: :string,
          description: "Model to pre-warm or unload",
          default: "llama3.2"
        },
        action: %{
          type: :string,
          description: "Cache action",
          enum: ["preload", "unload"],
          default: "preload"
        },
        keep_alive: %{
          type: [:string, :integer],
          description: "Duration string (e.g. '15m', '1h', -1) for preloading",
          default: "15m"
        }
      },
      required: ["model_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        model_name: %{type: :string},
        action: %{type: :string},
        status: %{type: :string}
      },
      required: ["model_name", "action", "status"]
    }

  alias Lux.LLM.Ollama

  @impl true
  def handler(inputs, _context) do
    model_name = Map.get(inputs, "model_name") || Map.get(inputs, :model_name, "llama3.2")
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "preload")
    keep_alive = Map.get(inputs, "keep_alive") || Map.get(inputs, :keep_alive, "15m")

    case action do
      "preload" ->
        case Ollama.preload_model(model_name, keep_alive) do
          {:ok, _} ->
            {:ok, %{model_name: model_name, action: "preload", status: "preloaded"}}

          {:error, reason} ->
            {:error, "Failed to preload model '#{model_name}': #{inspect(reason)}"}
        end

      "unload" ->
        case Ollama.unload_model(model_name) do
          {:ok, _} ->
            {:ok, %{model_name: model_name, action: "unload", status: "unloaded"}}

          {:error, reason} ->
            {:error, "Failed to unload model '#{model_name}': #{inspect(reason)}"}
        end

      other ->
        {:error, "Invalid action '#{other}'. Must be 'preload' or 'unload'"}
    end
  end
end
