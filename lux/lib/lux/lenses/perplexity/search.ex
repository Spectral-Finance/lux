defmodule Lux.Lenses.Perplexity.Search do
  @moduledoc """
  Search lens for Perplexity AI with citations and source attribution.
  Uses the chat completions endpoint optimized for search queries.

  ## Example

  ```elixir
  alias Lux.Lenses.Perplexity.Search

  Search.focus(%{
    query: "What is the current population of Tokyo?"
  })
  ```
  """

  use Lux.Lens,
    name: "Perplexity Search",
    description: "Search the web using Perplexity AI with citations",
    url: "https://api.perplexity.ai/chat/completions",
    method: :post,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Lenses.Perplexity.Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "Search query"
        },
        model: %{
          type: :string,
          description: "Model to use for search",
          enum: ["sonar", "sonar-pro", "sonar-deep-research"],
          default: "sonar-pro"
        }
      },
      required: ["query"]
    }

  @impl true
  def before_focus(params) do
    # Transform query into chat messages format expected by the API
    query = Map.get(params, :query)
    model = Map.get(params, :model, "sonar-pro")
    
    %{
      model: model,
      messages: [
        %{role: "user", content: query}
      ]
    }
  end

  @impl true
  def after_focus(%{"id" => _id, "choices" => choices} = response) do
    citations = response["citations"] || []
    
    transformed = %{
      answer: get_in(choices, [Access.at(0), "message", "content"]),
      citations: citations,
      usage: response["usage"]
    }

    {:ok, transformed}
  end

  @impl true
  def after_focus(response) do
    Lux.Lenses.Perplexity.Base.handle_response(response)
  end
end
