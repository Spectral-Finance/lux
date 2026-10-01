defmodule Lux.Prisms.Perplexity.ResearchAgent do
  @moduledoc """
  A multi-step research automation prism that uses Perplexity AI to investigate topics.

  ## Examples

      iex> Lux.Prisms.Perplexity.ResearchAgent.run(%{
      ...>   topic: "Quantum computing advancements in 2024",
      ...>   depth: "comprehensive"
      ...> })
  """

  use Lux.Prism,
    name: "Perplexity Research Agent",
    description: "Automates research on a topic using Perplexity AI with citations",
    input_schema: %{
      type: :object,
      properties: %{
        topic: %{
          type: :string,
          description: "Topic to research"
        },
        depth: %{
          type: :string,
          description: "Depth of research (basic, detailed, comprehensive)",
          enum: ["basic", "detailed", "comprehensive"],
          default: "detailed"
        }
      },
      required: ["topic"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        summary: %{
          type: :string,
          description: "Detailed research summary"
        },
        citations: %{
          type: :array,
          items: %{type: :string},
          description: "List of sources used"
        },
        model_used: %{
          type: :string,
          description: "Perplexity model used for research"
        }
      },
      required: ["summary", "citations", "model_used"]
    }

  alias Lux.Lenses.Perplexity.Search

  @doc """
  Executes the research process.
  """
  def handler(%{topic: topic} = input, _ctx) do
    depth = Map.get(input, :depth, "detailed")
    model = determine_model(depth)
    
    # Using the Search lens which uses the Perplexity API
    query = build_prompt(topic, depth)
    
    case Search.focus(%{query: query, model: model}) do
      {:ok, result} ->
        {:ok, %{
          summary: result.answer,
          citations: result.citations,
          model_used: model
        }}
        
      {:error, reason} ->
        {:error, "Research failed: #{inspect(reason)}"}
    end
  end

  defp determine_model("basic"), do: "sonar"
  defp determine_model("detailed"), do: "sonar-pro"
  defp determine_model("comprehensive"), do: "sonar-deep-research"
  defp determine_model(_), do: "sonar-pro"

  defp build_prompt(topic, "basic") do
    "Provide a brief overview of: #{topic}"
  end

  defp build_prompt(topic, "detailed") do
    "Provide a detailed research summary with key points and recent developments regarding: #{topic}"
  end

  defp build_prompt(topic, "comprehensive") do
    "Conduct a comprehensive, multi-faceted deep research on the following topic. Include historical context, current state, challenges, future outlook, and detailed technical or factual analysis where applicable. Topic: #{topic}"
  end
end
