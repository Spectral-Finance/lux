defmodule Lux.Prisms.YouTube.Videos.StartResumableUpload do
  @moduledoc """
  Starts a YouTube resumable video upload session.
  """

  use Lux.Prism,
    name: "Start YouTube Resumable Upload",
    description:
      "Initializes a YouTube Data API resumable upload session and returns the upload URL",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "Video title"},
        description: %{type: :string, description: "Video description"},
        privacy_status: %{
          type: :string,
          enum: ["private", "public", "unlisted"],
          default: "private"
        },
        tags: %{type: :array, items: %{type: :string}},
        content_type: %{type: :string, default: "video/*"},
        content_length: %{type: :integer, minimum: 0}
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        upload_url: %{type: :string},
        status: %{type: :integer}
      },
      required: ["upload_url", "status"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, title} <- required(params, :title) do
      metadata = %{
        snippet: %{
          title: title,
          description: params[:description] || "",
          tags: params[:tags] || []
        },
        status: %{
          privacyStatus: params[:privacy_status] || "private"
        }
      }

      headers =
        [{"X-Upload-Content-Type", params[:content_type] || "video/*"}]
        |> maybe_add_length(params[:content_length])

      opts = [
        base: :upload,
        token: params[:token],
        params: %{uploadType: "resumable", part: "snippet,status"},
        json: metadata,
        headers: headers,
        plug: params[:plug]
      ]

      case Client.raw_request(:post, "/videos", opts) do
        {:ok, %{status: status} = response} when status in 200..299 ->
          case Client.response_header(response, "location") do
            nil -> {:error, "YouTube did not return a resumable upload URL"}
            upload_url -> {:ok, %{upload_url: upload_url, status: status}}
          end

        {:ok, %{status: status, body: body}} ->
          {:error, {status, body}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp maybe_add_length(headers, nil), do: headers

  defp maybe_add_length(headers, length),
    do: headers ++ [{"X-Upload-Content-Length", to_string(length)}]

  defp required(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
