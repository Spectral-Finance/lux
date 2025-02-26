# Test tools that perform real operations
defmodule Test.Support.Companies.ContentTeam.SearchPrism do
  @moduledoc false
  use Lux.Prism,
    name: "SearchPrism",
    description: "Searches for information in a given text",
    input_schema: %{
      type: "object",
      properties: %{
        "query" => %{
          type: "string",
          description: "The search query"
        },
        "text" => %{
          type: "string",
          description: "The text to search in"
        }
      },
      required: ["query", "text"]
    },
    capabilities: ["search", "analyze"]

  def handler(%{"query" => query, "text" => text}, _context) do
    if String.contains?(String.downcase(text), String.downcase(query)) do
      {:ok,
       %{
         found: true,
         matches: [text]
       }}
    else
      {:ok,
       %{
         found: false,
         matches: []
       }}
    end
  end
end

defmodule Test.Support.Companies.ContentTeam.SummarizeLens do
  @moduledoc false
  use Lux.Lens,
    name: "SummarizeLens",
    description: "Summarizes a given text",
    schema: %{
      type: "object",
      properties: %{
        "text" => %{
          type: "string",
          description: "The text to summarize"
        },
        "max_length" => %{
          type: "integer",
          description: "Maximum length of the summary",
          default: 100
        }
      },
      required: ["text"]
    },
    capabilities: ["summarize", "analyze"]

  def call(%{"text" => text, "max_length" => max_length}, _context) do
    summary = String.slice(text, 0, max_length)
    {:ok, %{summary: summary}}
  end
end

# Define test agent using company_agent template
defmodule Test.Support.Companies.ContentTeam.TestAgent do
  @moduledoc false
  use Lux.Agent,
    template: :company_agent,
    name: "TestAgent",
    description: "A test agent for integration testing",
    capabilities: ["analyze", "search", "summarize"],
    signal_handlers: [
      {Lux.Schemas.Companies.TaskSignal,
       {Lux.Agent.Companies.SignalHandler.DefaultImplementation, :handle_task_assignment}}
    ],
    template_opts: %{
      llm_config: %{
        provider: :open_ai,
        model: Lux.Config.runtime(:open_ai_models, [:default]),
        temperature: 0.7,
        max_tokens: 500,
        api_key: Lux.Config.runtime(:api_keys, [:integration_openai])
      }
    }
end

defmodule Test.Support.Companies.ContentTeam do
  @moduledoc """
  Defines a content creation company for testing purposes.
  Includes a CEO (Content Director), a researcher, and a writer.
  """
  use Lux.Company

  company do
    name("Content Creation Team")
    mission("Create high-quality content efficiently through collaboration")

    has_ceo "Content Director" do
      agent(Test.Support.Agents.ContentDirector)
      goal("Direct content creation and ensure quality")
      can("review")
      can("approve")
      can("plan")
    end

    members do
      has_role "Research Specialist" do
        agent(Test.Support.Agents.Researcher)
        goal("Research topics and provide comprehensive insights")
        can("research")
        can("analyze")
        can("summarize")
      end

      has_role "Content Writer" do
        agent(Test.Support.Agents.Writer)
        goal("Create engaging and well-structured content")
        can("write")
        can("edit")
        can("draft")
      end
    end
  end

  objective :create_blog_post do
    description("Create a well-researched blog post")

    success_criteria(
      "Well-researched content with cited sources, engaging writing style, proper structure, and approved by Content Director"
    )

    steps([
      "Research the topic thoroughly and gather key insights",
      "Create a detailed outline based on research",
      "Write the first draft following the outline",
      "Review and edit the content",
      "Get final approval from Content Director"
    ])

    input(%{
      required: ["topic", "target_audience", "tone"],
      properties: %{
        "topic" => %{type: "string", description: "The topic to write about"},
        "target_audience" => %{
          type: "string",
          description: "The intended audience for the blog post"
        },
        "tone" => %{type: "string", description: "The writing tone/style to use"}
      }
    })
  end
end
