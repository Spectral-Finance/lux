defmodule Lux.Prisms.Llm.OpenRouter.ModelRoutePrism do
  @moduledoc """
  A prism for selecting the most appropriate OpenRouter model and fallback cascade
  based on requirements such as strategy (smartest/balanced/fastest/cheapest/free),
  context window requirements, tool support, and cost constraints.
  """

  use Lux.Prism,
    name: "OpenRouter Model Route",
    description: "Evaluates requirements and selects the optimal OpenRouter model and fallback chain",
    input_schema: %{
      type: :object,
      properties: %{
        strategy: %{
          type: :string,
          description: "Selection strategy",
          enum: ["smartest", "balanced", "fastest", "cheapest", "free"],
          default: "balanced"
        },
        min_context: %{
          type: :integer,
          description: "Minimum context length required (in tokens)",
          default: 0
        },
        tools_required: %{
          type: :boolean,
          description: "Whether function/tool calling support is required",
          default: false
        },
        vision_required: %{
          type: :boolean,
          description: "Whether image/multimodal input support is required",
          default: false
        },
        max_prompt_price: %{
          type: :number,
          description: "Maximum acceptable price per 1M prompt tokens (in USD)"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        selected_model: %{type: :string},
        fallback_chain: %{type: :array, items: %{type: :string}},
        pricing: %{type: :object},
        context_length: %{type: :integer}
      },
      required: ["selected_model", "fallback_chain"]
    }

  alias Lux.LLM.OpenRouter.ModelRouter

  @impl true
  def handler(inputs, _context) do
    strategy_str = Map.get(inputs, "strategy") || Map.get(inputs, :strategy, "balanced")
    strategy = parse_strategy(strategy_str)
    min_context = Map.get(inputs, "min_context") || Map.get(inputs, :min_context, 0)
    tools_required = Map.get(inputs, "tools_required") || Map.get(inputs, :tools_required, false)
    vision_required = Map.get(inputs, "vision_required") || Map.get(inputs, :vision_required, false)
    max_prompt_price = Map.get(inputs, "max_prompt_price") || Map.get(inputs, :max_prompt_price)

    opts = [
      strategy: strategy,
      min_context: min_context,
      tools_required: tools_required,
      vision_required: vision_required
    ]

    opts = if is_number(max_prompt_price), do: Keyword.put(opts, :max_prompt_price, max_prompt_price), else: opts

    selected_model = ModelRouter.select_model(opts)
    fallback_chain = ModelRouter.build_fallback_chain(selected_model)

    catalog_entry = Map.get(ModelRouter.curated_catalog(), selected_model, %{
      pricing: %{prompt: 1.0, completion: 2.0},
      context_length: 128_000
    })

    {:ok,
     %{
       selected_model: selected_model,
       fallback_chain: fallback_chain,
       pricing: catalog_entry.pricing,
       context_length: catalog_entry.context_length
     }}
  end

  defp parse_strategy("smartest"), do: :smartest
  defp parse_strategy("cheapest"), do: :cheapest
  defp parse_strategy("fastest"), do: :fastest
  defp parse_strategy("free"), do: :free
  defp parse_strategy("balanced"), do: :balanced
  defp parse_strategy(atom) when is_atom(atom), do: atom
  defp parse_strategy(_), do: :balanced
end
