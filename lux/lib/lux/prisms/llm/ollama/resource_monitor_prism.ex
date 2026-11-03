defmodule Lux.Prisms.Llm.Ollama.ResourceMonitorPrism do
  @moduledoc """
  A prism that queries active memory/VRAM consumption and loaded models on the Ollama instance.
  """

  use Lux.Prism,
    name: "Ollama Resource Monitor",
    description: "Inspects running models, VRAM footprint, and Ollama service availability",
    input_schema: %{
      type: :object,
      properties: %{
        endpoint: %{
          type: :string,
          description: "Optional custom Ollama endpoint"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        healthy: %{type: :boolean},
        active_models_count: %{type: :integer},
        running_models: %{type: :array, items: %{type: :string}},
        total_vram_mb: %{type: :number},
        total_vram_gb: %{type: :number}
      },
      required: ["healthy", "active_models_count", "total_vram_mb"]
    }

  alias Lux.LLM.Ollama.ResourceMonitor

  @impl true
  def handler(inputs, _context) do
    endpoint = Map.get(inputs, "endpoint") || Map.get(inputs, :endpoint)
    opts = if endpoint, do: [endpoint: endpoint], else: []

    case ResourceMonitor.get_vram_usage(opts) do
      {:ok, data} ->
        {:ok,
         %{
           healthy: true,
           active_models_count: data.active_models_count,
           running_models: data.running_models,
           total_vram_mb: data.total_vram_mb,
           total_vram_gb: data.total_vram_gb
         }}

      {:error, reason} ->
        {:ok,
         %{
           healthy: false,
           active_models_count: 0,
           running_models: [],
           total_vram_mb: 0.0,
           total_vram_gb: 0.0,
           error: inspect(reason)
         }}
    end
  end
end
