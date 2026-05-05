defmodule Lux.Prisms.YouTube.Videos.InsertVideo do
  @moduledoc "Starts resumable YouTube video upload sessions with metadata."

  use Lux.Prism,
    name: "Start YouTube Video Upload",
    description: "Creates a YouTube Data API v3 resumable upload session for a video",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        privacy_status: %{type: :string, enum: ["private", "public", "unlisted"]},
        mime_type: %{type: :string},
        content_length: %{type: :integer}
      },
      required: ["title", "mime_type", "content_length"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, title} <- required(params, :title),
         {:ok, mime_type} <- required(params, :mime_type),
         {:ok, content_length} <- required_integer(params, :content_length),
         {:ok, response} <- Client.request(:post, "/videos", %{
           endpoint: :upload,
           params: %{uploadType: "resumable", part: "snippet,status"},
           headers: [
             {"X-Upload-Content-Type", mime_type},
             {"X-Upload-Content-Length", to_string(content_length)}
           ],
           json: %{
             snippet: %{
               title: title,
               description: value(params, :description, "")
             },
             status: %{
               privacyStatus: value(params, :privacy_status, "private"),
               selfDeclaredMadeForKids: value(params, :self_declared_made_for_kids, false)
             }
           }
         }) do
      {:ok, %{upload_url: response["upload_url"], resumable: true}}
    end
  end

  defp required(params, key) do
    case value(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp required_integer(params, key) do
    case value(params, key) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, ""} when int > 0 -> {:ok, int}
          _ -> {:error, "Missing or invalid #{key}"}
        end
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp value(params, key, default \\ nil), do: Map.get(params, key) || Map.get(params, to_string(key)) || default
end
