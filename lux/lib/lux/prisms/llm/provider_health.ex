defmodule Lux.Prisms.Llm.ProviderHealthPrism do
  @moduledoc """
  Inspects provider health status, latency, and supported capabilities.
  """

  use Lux.Prism,
    name: "LLM Provider Health",
    description: "Retrieves health status, latency, and supported models for an LLM provider",
    input_schema: %{
      type: :object,
      properties: %{
        provider: %{type: :string, description: "Provider name, e.g. openai, anthropic"}
      },
      required: ["provider"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        provider: %{type: :string},
        status: %{type: :string},
        avg_latency_ms: %{type: :integer},
        models: %{type: :array}
      },
      required: ["provider", "status"]
    }

  alias Lux.LLM.ProviderRegistry

  def handler(input, _ctx) do
    prov_str = Map.get(input, :provider) || Map.get(input, "provider", "openai")
    prov_atom = prov_str |> String.downcase() |> String.to_atom()

    case ProviderRegistry.get_provider(prov_atom) do
      {:ok, meta} ->
        {:ok,
         %{
           provider: to_string(prov_atom),
           status: to_string(meta.status),
           avg_latency_ms: meta.avg_latency_ms,
           models: meta.models
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
