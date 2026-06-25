defmodule Lux.Agents.YouTube.ContentTester do
  @moduledoc """
  An agent that sets up A/B tests and analyzes content performance.
  """

  use Lux.Agent,
    name: "YouTube Content Tester",
    description: "Sets up A/B tests for thumbnails/titles and analyzes metrics",
    goal: "Evaluate content variations to identify top-performing combinations",
    capabilities: [:ab_testing, :performance_analysis, :variation_generation, :content_repurposing],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.7,
      json_response: true,
      json_schema: %{
        name: "content_testing_plan",
        schema: %{
          type: "object",
          properties: %{
            variations: %{
              type: "array",
              items: %{
                type: "object",
                properties: %{
                  title: %{type: "string"},
                  thumbnail_concept: %{type: "string"},
                  hypothesis: %{type: "string"}
                },
                required: ["title", "thumbnail_concept", "hypothesis"]
              },
              description: "Different variations to test"
            },
            test_duration_days: %{
              type: "integer",
              description: "Recommended test duration"
            },
            success_metrics: %{
              type: "array",
              items: %{type: "string"},
              description: "Metrics to track (e.g., CTR, AVD)"
            },
            repurposed_content: %{
              type: "object",
              description: "Short-form content scripts and Twitter threads generated from the video brief",
              properties: %{
                "shorts_transcript" => %{type: "string"},
                "twitter_thread" => %{
                  type: "array",
                  items: %{type: "string"}
                }
              },
              required: ["shorts_transcript", "twitter_thread"]
            }
          },
          required: ["variations", "test_duration_days", "success_metrics", "repurposed_content"]
        }
      },
      messages: [
        %{
          role: "system",
          content: """
          You are a YouTube Analytics & Testing expert. 
          Generate A/B testing frameworks for video content by proposing distinct variations
          with clear hypotheses and success metrics.
          Your output must be valid JSON matching the required schema.
          """
        }
      ]
    }

  def generate_test_plan(agent, metadata, visual_plan) do
    send_message(agent, """
    Base Metadata: #{Jason.encode!(metadata)}
    Visual Plan: #{Jason.encode!(visual_plan)}
    
    Create a comprehensive A/B testing plan for this video.
    """)
  end
end
