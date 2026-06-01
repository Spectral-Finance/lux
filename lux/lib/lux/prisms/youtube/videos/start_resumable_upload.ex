defmodule Lux.Prisms.YouTube.Videos.StartResumableUpload do
  @moduledoc """
  Starts a YouTube resumable video upload session.
  """

  use Lux.Prism,
    name: "Start YouTube Resumable Upload",
    description: "Creates a resumable upload session and returns the session URL",
    input_schema: %{
      type: :object,
      properties: %{
        access_token: %{type: :string},
        title: %{type: :string},
        description: %{type: :string},
        privacy_status: %{type: :string, enum: ["private", "unlisted", "public"]},
        content_type: %{type: :string},
        content_length: %{type: :integer}
      },
      required: ["access_token", "title"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(input, _context) do
    metadata = %{
      snippet: %{
        title: Client.get(input, :title),
        description: Client.get(input, :description, "")
      },
      status: %{
        privacyStatus: Client.get(input, :privacy_status, "private")
      }
    }

    Client.start_resumable_upload(metadata, input)
  end
end
