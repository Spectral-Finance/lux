defmodule Lux.Companies.YouTubePipeline do
  @moduledoc """
  An automated content creation and optimization pipeline for YouTube channels.
  Coordinates script generation, visual optimization, metadata management, and A/B testing.
  """
  use Lux.Company

  company do
    name("YouTube Content Creation Pipeline")
    mission("Produce high-quality, fully optimized YouTube videos from raw concepts")

    has_ceo "Content Director" do
      agent(Lux.Agents.YouTube.ScriptGenerator)
      goal("Direct the overall video creation and ensure script quality")
      can("script_generation")
      can("hook_writing")
      can("content_structuring")
      can("editing_suggestions")
    end

    members do
      has_role "Visual Optimizer" do
        agent(Lux.Agents.YouTube.VisualOptimizer)
        goal("Optimize thumbnails and video pacing")
        can("thumbnail_ideation")
        can("broll_suggestion")
        can("pacing_analysis")
      end

      has_role "Metadata Manager" do
        agent(Lux.Agents.YouTube.MetadataManager)
        goal("Maximize SEO and search discovery")
        can("seo_optimization")
        can("tag_generation")
        can("description_writing")
        can("playlist_organization")
        can("localization")
      end

      has_role "Content Tester" do
        agent(Lux.Agents.YouTube.ContentTester)
        goal("A/B test variations to ensure high CTR")
        can("ab_testing")
        can("performance_analysis")
        can("variation_generation")
        can("content_repurposing")
      end
    end
  end

  objective :create_optimized_video do
    description("Takes a raw topic and generates a complete, optimized YouTube content package")

    success_criteria(
      "Script, visual plan, metadata, and testing plan are all generated and mutually consistent"
    )

    steps([
      %{
        "name" => "Generate the script and hook based on the topic",
        "required_capabilities" => ["script_generation"]
      },
      %{
        "name" => "Generate automated editing suggestions",
        "required_capabilities" => ["editing_suggestions"]
      },
      %{
        "name" => "Propose visual optimization (thumbnails and b-roll) based on the script",
        "required_capabilities" => ["thumbnail_ideation"]
      },
      %{
        "name" => "Generate SEO-optimized metadata",
        "required_capabilities" => ["seo_optimization"]
      },
      %{
        "name" => "Organize playlists and generate localized metadata",
        "required_capabilities" => ["playlist_organization", "localization"]
      },
      %{
        "name" => "Create an A/B testing plan for the generated assets",
        "required_capabilities" => ["ab_testing"]
      },
      %{
        "name" => "Repurpose content for other platforms",
        "required_capabilities" => ["content_repurposing"]
      }
    ])

    input(%{
      required: ["topic", "target_audience"],
      properties: %{
        "topic" => %{
          type: "string",
          description: "The main topic or idea for the YouTube video"
        },
        "target_audience" => %{
          type: "object",
          description: "Details about the target audience demographics and interests",
          properties: %{
            "age_range" => %{type: "string"},
            "interests" => %{type: "array", items: %{type: "string"}}
          }
        }
      }
    })
  end
end
