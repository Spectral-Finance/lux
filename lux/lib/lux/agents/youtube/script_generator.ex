defmodule Lux.Agents.YouTube.ScriptGenerator do
  @moduledoc """
  An agent that generates highly engaging YouTube scripts based on topics and audience analysis.
  """

  use Lux.Agent,
    name: "YouTube Script Generator",
    description: "Generates YouTube scripts, outlines, and hooks",
    goal: "Create high-retention, engaging video scripts tailored to specific audiences",
    capabilities: [:script_generation, :hook_writing, :content_structuring, :editing_suggestions],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.7,
      json_response: true,
      json_schema: %{
        name: "script_generation",
        schema: %{
          type: "object",
          properties: %{
            title_ideas: %{
              type: "array",
              items: %{type: "string"},
              description: "List of 3-5 high-CTR title ideas"
            },
            hook: %{
              type: "string",
              description: "A captivating hook for the first 15 seconds"
            },
            outline: %{
              type: "array",
              items: %{type: "string"},
              description: "Main sections of the video"
            },
            full_script: %{
              type: "string",
              description: "The complete word-for-word script"
            },
            estimated_duration: %{
              type: "number",
              description: "Estimated video duration in minutes"
            },
            editing_suggestions: %{
              type: "array",
              items: %{type: "string"},
              description: "Automated suggestions for editing, graphics, sound effects, and transitions"
            }
          },
          required: ["title_ideas", "hook", "outline", "full_script", "estimated_duration", "editing_suggestions"]
        }
      },
      messages: [
        %{
          role: "system",
          content: """
          You are an expert YouTube scriptwriter focused on high retention and engagement.
          Generate comprehensive scripts with engaging hooks, clear structures, and compelling calls to action.
          Your output must be valid JSON matching the required schema.
          """
        }
      ]
    }

  def generate_script(agent, topic, audience_details \\ %{}) do
    send_message(agent, """
    Topic: #{topic}
    Audience Details: #{Jason.encode!(audience_details)}
    
    Create a highly engaging YouTube script for this topic.
    """)
  end
end
