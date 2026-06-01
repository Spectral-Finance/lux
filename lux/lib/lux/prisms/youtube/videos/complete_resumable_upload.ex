defmodule Lux.Prisms.YouTube.Videos.CompleteResumableUpload do
  @moduledoc """
  Uploads bytes to an existing YouTube resumable upload session.
  """

  use Lux.Prism,
    name: "Complete YouTube Resumable Upload",
    description: "Uploads video bytes to a YouTube resumable upload session URL",
    input_schema: %{
      type: :object,
      properties: %{
        access_token: %{type: :string},
        session_url: %{type: :string},
        video_bytes: %{type: :string},
        content_type: %{type: :string}
      },
      required: ["session_url", "video_bytes"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(input, _context) do
    Client.complete_resumable_upload(
      Client.get(input, :session_url),
      Client.get(input, :video_bytes),
      input
    )
  end
end
