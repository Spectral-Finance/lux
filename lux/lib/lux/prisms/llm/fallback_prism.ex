defmodule Lux.Prisms.LLM.FallbackPrism do
  @moduledoc """
  A prism that manages fallback orchestration across multiple LLM providers.
  """

  use Lux.Prism,
    name: "LLM Fallback Prism",
    description: "Executes LLM request with automated failover across fallback chain",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{type: :string},
        fallback_chain: %{
          type: :array,
          items: %{type: :string},
          description: "List of provider names to try in sequence"
        },
        tools: %{type: :array, default: []}
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content: %{type: [:string, :null]},
        successful_provider: %{type: :string},
        attempts_count: %{type: :integer},
        success: %{type: :boolean}
      },
      required: ["successful_provider", "attempts_count", "success"]
    }

  alias Lux.LLM.FallbackManager

  @impl true
  def handler(inputs, _context) do
    prompt = Map.get(inputs, "prompt") || Map.get(inputs, :prompt)
    tools = Map.get(inputs, "tools") || Map.get(inputs, :tools, [])
    chain_raw = Map.get(inputs, "fallback_chain") || Map.get(inputs, :fallback_chain, [])

    chain =
      Enum.map(chain_raw, fn
        item when is_binary(item) -> String.to_atom(item)
        item when is_atom(item) -> item
      end)

    opts = if chain != [], do: %{fallback_chain: chain}, else: %{}

    case FallbackManager.execute_with_fallback(prompt, tools, opts) do
      {:ok, resp, meta} ->
        {:ok,
         %{
           content: resp.content,
           successful_provider: to_string(meta.successful_provider),
           attempts_count: meta.attempts_count,
           success: true
         }}

      {:error, reason, _attempts} ->
        {:error, "Fallback chain exhausted: #{inspect(reason)}"}
    end
  end
end
