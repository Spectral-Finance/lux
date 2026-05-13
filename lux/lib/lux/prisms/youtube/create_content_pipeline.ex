defmodule Lux.Prisms.YouTube.CreateContentPipeline do
  @moduledoc """
  Builds a YouTube content creation pipeline from a channel brief.
  """

  use Lux.Prism,
    name: "YouTube Content Creation Pipeline",
    description: "Generates script, editing, thumbnail, metadata, playlist, localization, repurposing, and testing plans.",
    input_schema: %{
      type: :object,
      properties: %{
        topic: %{type: :string, description: "Video topic"},
        target_audience: %{type: :string, description: "Primary viewer segment"},
        goal: %{type: :string, description: "Viewer outcome or channel goal"},
        tone: %{type: :string, description: "Script and metadata tone"},
        format: %{type: :string, description: "Video format, such as tutorial or review"},
        duration_minutes: %{type: :integer, description: "Target duration in minutes"},
        keywords: %{type: :array, items: %{type: :string}},
        languages: %{type: :array, items: %{type: :string}},
        existing_playlists: %{type: :array, items: %{type: :string}},
        assets: %{type: :array, items: %{type: :string}}
      },
      required: ["topic", "target_audience", "goal"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        brief: %{type: :object},
        script: %{type: :object},
        editing: %{type: :object},
        visual_optimization: %{type: :object},
        metadata: %{type: :object},
        playlist: %{type: :object},
        localization: %{type: :object},
        repurposing: %{type: :object},
        testing: %{type: :object},
        handoff: %{type: :object}
      }
    }

  alias Lux.Integrations.YouTube.ContentPipeline

  def handler(input, _context) do
    ContentPipeline.run(input)
  end
end
