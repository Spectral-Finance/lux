defmodule Lux.Prisms.YouTube.Videos.GetUploadStatus do
  @moduledoc """
  Checks the committed byte range for a YouTube resumable upload session.
  """

  use Lux.Prism,
    name: "Get YouTube Upload Status",
    description: "Checks whether a YouTube resumable upload session is complete or resumable",
    input_schema: %{
      type: :object,
      properties: %{
        access_token: %{type: :string},
        session_url: %{type: :string},
        total_size: %{type: :integer}
      },
      required: ["session_url"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(input, _context) do
    input
    |> Client.get(:session_url)
    |> Client.upload_status(input)
  end
end
