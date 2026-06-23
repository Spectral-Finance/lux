defmodule Lux.Beams.YouTube.ContentCreationPipelineBeam do
  @moduledoc """
  Orchestrates the entire YouTube content creation pipeline.
  """
  use Lux.Beam,
    name: "YouTube Content Creation Pipeline",
    description: "Generates script, thumbnail, and uploads to YouTube",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{type: :string},
        playlist_id: %{type: :string},
        access_token: %{type: :string}
      },
      required: ["prompt", "playlist_id", "access_token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        playlist_success: %{type: :boolean}
      },
      required: ["video_id", "playlist_success"]
    }

  sequence do
    step(:script_gen, Lux.Prisms.YouTube.ScriptGeneratorPrism, %{prompt: [:input, :prompt]})
    step(:metadata_gen, Lux.Prisms.YouTube.MetadataGeneratorPrism, %{script: [:steps, :script_gen, :result, :script]})
    step(:thumbnail_gen, Lux.Prisms.YouTube.ThumbnailGeneratorPrism, %{prompt: [:input, :prompt]})
    
    step(:dummy_video_creator, Lux.Prisms.YouTube.DummyVideoCreatorPrism, %{
      title: [:steps, :metadata_gen, :result, :title]
    })
    
    step(:upload, Lux.Prisms.YouTube.UploadVideoPrism, %{
      video_path: [:steps, :dummy_video_creator, :result, :video_path],
      access_token: [:input, :access_token],
      title: [:steps, :metadata_gen, :result, :title],
      description: [:steps, :metadata_gen, :result, :description]
    })
    
    step(:set_metadata, Lux.Prisms.YouTube.SetMetadataPrism, %{
      video_id: [:steps, :upload, :result, :video_id],
      title: [:steps, :metadata_gen, :result, :title],
      description: [:steps, :metadata_gen, :result, :description],
      tags: [:steps, :metadata_gen, :result, :tags],
      access_token: [:input, :access_token]
    })
    
    step(:add_to_playlist, Lux.Prisms.YouTube.PlaylistManagerPrism, %{
      video_id: [:steps, :upload, :result, :video_id],
      playlist_id: [:input, :playlist_id],
      access_token: [:input, :access_token]
    })
    
    step(:format_output, Lux.Prisms.YouTube.FormatPipelineOutputPrism, %{
      video_id: [:steps, :upload, :result, :video_id],
      playlist_success: [:steps, :add_to_playlist, :result, :success]
    })
  end
end
