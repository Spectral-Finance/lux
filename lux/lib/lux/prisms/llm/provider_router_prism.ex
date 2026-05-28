defmodule Lux.Prisms.LLM.ProviderRouterPrism do
  @moduledoc """
  Prism wrapper for Lux's LLM provider registry.

  Agents can use this prism to pick an LLM provider/model before running a
  costly call, or to explain the fallback chain selected for a request.
  """

  use Lux.Prism,
    name: "LLM Provider Router",
    description: "Selects an LLM provider/model using capabilities, cost, latency, and quality preferences.",
    input_schema: %{
      type: :object,
      properties: %{
        capabilities: %{
          type: :array,
          items: %{type: :string},
          description: "Required provider capabilities such as chat, tools, json_schema, or vision."
        },
        provider: %{type: :string, description: "Optional provider id to force, for example open_ai."},
        model: %{type: :string, description: "Optional model id to force."},
        strategy: %{
          type: :string,
          enum: ["balanced", "cost", "latency", "quality"],
          description: "Routing strategy."
        },
        input_tokens: %{type: :integer, minimum: 0},
        output_tokens: %{type: :integer, minimum: 0},
        max_cost: %{type: :number, minimum: 0}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        provider: %{type: :string},
        module: %{type: :string},
        model: %{type: :string},
        estimated_cost: %{type: :number},
        fallback_chain: %{type: :array}
      },
      required: ["provider", "module", "model", "estimated_cost", "fallback_chain"]
    }

  alias Lux.LLM.ProviderRegistry

  def handler(input, _ctx) do
    with {:ok, selection} <-
           ProviderRegistry.select(ProviderRegistry.default_registry(), normalize_input(input)) do
      {:ok,
       %{
         provider: Atom.to_string(selection.provider.id),
         module: inspect(selection.provider.module),
         model: selection.model,
         estimated_cost: selection.estimated_cost,
         fallback_chain:
           Enum.map(selection.fallback_chain, fn {provider, model} ->
             %{provider: Atom.to_string(provider), model: model}
           end)
       }}
    end
  end

  defp normalize_input(input) do
    input
    |> Enum.map(fn
      {key, value} when is_binary(key) -> {String.to_atom(key), value}
      entry -> entry
    end)
    |> Map.new()
  end
end
