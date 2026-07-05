defmodule Lux.Agents.YouTube.VisualOptimizer do
  @moduledoc """
  An agent that proposes visual content strategies including thumbnails and b-roll suggestions.
  """

  use Lux.Agent,
    name: "YouTube Visual Optimizer",
    description: "Suggests thumbnail designs, b-roll, and visual pacing for videos",
    goal: "Optimize visual elements for maximum click-through and retention",
    capabilities: [:thumbnail_ideation, :broll_suggestion, :pacing_analysis],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.7,
      json_response: true,
      json_schema: %{
        name: "visual_optimization",
        schema: %{
          type: "object",
          properties: %{
            thumbnail_prompts: %{
              type: "array",
              items: %{type: "string"},
              description: "Image generation prompts for thumbnail ideas"
            },
            broll_suggestions: %{
              type: "array",
              items: %{type: "string"},
              description: "Suggested b-roll or stock footage with timestamps"
            },
            color_palette: %{
              type: "array",
              items: %{type: "string"},
              description: "Recommended hex colors for branding/mood"
            },
            end_screen_layout: %{
              type: "string",
              description: "Suggestion for end screen card placements"
            },
            card_placements: %{
              type: "array",
              items: %{type: "string"},
              description: "Suggestions for info cards and poll placements with timestamps"
            }
          },
          required: ["thumbnail_prompts", "broll_suggestions", "color_palette", "end_screen_layout", "card_placements"]
        }
      },
      messages: [
        %{
          role: "system",
          content: """
          You are a YouTube visual optimization expert. Your role is to conceptualize high-converting thumbnails,
          suggest engaging b-roll, and optimize end screens for maximum retention.
          Your output must be valid JSON matching the required schema.
          """
        }
      ]
    }

  def optimize_visuals(agent, script, title) do
    send_message(agent, """
    Video Title: #{title}
    Script Snippet/Outline: #{String.slice(script, 0, 1000)}...
    
    Provide visual optimization suggestions including thumbnails, b-roll, and end screens.
    """)
  end
end
