defmodule Lux.Beams.Llm.Perplexity.PerplexityResearchBeam do
  @moduledoc """
  A beam orchestrating online web research through Perplexity AI:
  1. Configures search domain filters and recency parameters.
  2. Executes online inference using Perplexity Sonar models.
  3. Formats citations into structured reference links and markdown footnotes.

  ## Example Usage

  ```elixir
  {:ok, result, execution_log} = Lux.Beams.Llm.Perplexity.PerplexityResearchBeam.run(%{
    prompt: "What were the latest SEC rulings on Ethereum staking?",
    model: "sonar-pro",
    allowed_domains: ["sec.gov", "coindesk.com", "bloomberg.com"],
    recency: "month"
  })
  ```
  """

  use Lux.Beam,
    name: "Perplexity Research Pipeline",
    description: "Orchestrates online search filters, web grounding, and citation formatting with Perplexity AI",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "Research topic or query"
        },
        model: %{
          type: :string,
          description: "Perplexity model (e.g. 'sonar', 'sonar-pro', 'sonar-reasoning')",
          default: "sonar-pro"
        },
        allowed_domains: %{
          type: :array,
          items: %{type: :string},
          description: "List of domain names to restrict search to"
        },
        blocked_domains: %{
          type: :array,
          items: %{type: :string},
          description: "List of domain names to exclude"
        },
        recency: %{
          type: :string,
          description: "Time recency filter ('day', 'week', 'month', 'year')"
        },
        api_key: %{
          type: :string,
          description: "Optional Perplexity API key override"
        }
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        annotated_content: %{type: [:string, :null]},
        count: %{type: :integer},
        references: %{type: :array}
      },
      required: ["count", "references"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Llm.Perplexity.CitationPrism
  alias Lux.Prisms.Llm.Perplexity.DomainFilterPrism
  alias Lux.Prisms.Llm.Perplexity.SearchChatPrism

  sequence do
    # Step 1: Set up search domain rules and recency constraints
    step(:filter_setup, DomainFilterPrism, %{
      allowed_domains: [:input, :allowed_domains],
      blocked_domains: [:input, :blocked_domains],
      recency: [:input, :recency]
    })

    # Step 2: Execute search inference
    step(:search_inference, SearchChatPrism, %{
      prompt: [:input, :prompt],
      model: [:input, :model],
      search_domain_filter: [:steps, :filter_setup, :search_domain_filter],
      search_recency_filter: [:steps, :filter_setup, :search_recency_filter],
      api_key: [:input, :api_key]
    })

    # Step 3: Format citations into markdown references
    step(:citation_formatting, CitationPrism, %{
      citations: [:steps, :search_inference, :citations],
      content: [:steps, :search_inference, :content]
    })
  end
end
