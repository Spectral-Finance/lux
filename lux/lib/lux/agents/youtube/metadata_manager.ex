defmodule Lux.Agents.YouTube.MetadataManager do
  @moduledoc """
  An agent that manages and optimizes YouTube video metadata (titles, descriptions, tags).
  """

  use Lux.Agent,
    name: "YouTube Metadata Manager",
    description: "Optimizes SEO metadata for YouTube videos",
    goal: "Maximize search discovery and click-through rates via optimized metadata",
    capabilities: [:seo_optimization, :tag_generation, :description_writing, :playlist_organization, :localization],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.7,
      json_response: true,
      json_schema: %{
        name: "metadata_optimization",
        schema: %{
          type: "object",
          properties: %{
            optimized_title: %{
              type: "string",
              description: "The best performing title for the video"
            },
            description: %{
              type: "string",
              description: "SEO optimized video description including timestamps and links"
            },
            tags: %{
              type: "array",
              items: %{type: "string"},
              description: "List of relevant SEO tags"
            },
            category_id: %{
              type: "string",
              description: "Recommended YouTube category ID (e.g., '22' for People & Blogs)"
            },
            playlist_organization: %{
              type: "array",
              items: %{type: "string"},
              description: "Recommended playlists to add this video to"
            },
            multi_language_support: %{
              type: "object",
              description: "Translated titles and descriptions for multi-language audience reach",
              properties: %{
                "es" => %{
                  type: "object",
                  properties: %{
                    title: %{type: "string"},
                    description: %{type: "string"}
                  },
                  required: ["title", "description"]
                }
              },
              required: ["es"]
            }
          },
          required: ["optimized_title", "description", "tags", "category_id", "playlist_organization", "multi_language_support"]
        }
      },
      messages: [
        %{
          role: "system",
          content: """
          You are a YouTube SEO expert. Your role is to generate optimized titles, comprehensive descriptions, 
          and high-value tags that improve search ranking and recommendation algorithms.
          Your output must be valid JSON matching the required schema.
          """
        }
      ]
    }

  def generate_metadata(agent, script, visual_plan) do
    send_message(agent, """
    Script Summary: #{String.slice(script, 0, 1000)}...
    Visual Plan: #{Jason.encode!(visual_plan)}
    
    Generate SEO-optimized metadata for this video.
    """)
  end
end
