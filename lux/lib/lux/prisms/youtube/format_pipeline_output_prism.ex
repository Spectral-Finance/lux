defmodule Lux.Prisms.YouTube.FormatPipelineOutputPrism do
  @moduledoc false
  use Lux.Prism,
    name: "Format Output",
    description: "Formats pipeline output",
    input_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        playlist_success: %{type: :boolean}
      },
      required: ["video_id", "playlist_success"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        playlist_success: %{type: :boolean}
      },
      required: ["video_id", "playlist_success"]
    }
    
  def handler(input, _ctx), do: {:ok, input}
end
