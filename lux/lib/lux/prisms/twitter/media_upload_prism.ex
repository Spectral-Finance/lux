defmodule Lux.Prisms.Twitter.MediaUploadPrism do
  @moduledoc """
  Prism for uploading media to Twitter via the v1.1 API.
  Uses the chunked upload strategy (INIT, APPEND, FINALIZE).
  """
  use Lux.Prism,
    name: "Media Upload",
    description: "Uploads media to Twitter API using chunked upload",
    input_schema: %{
      type: :object,
      properties: %{
        token: %{type: :string, description: "OAuth 2.0 Bearer token or User token"},
        media_data: %{type: :string, description: "Raw binary data of the media"},
        media_type: %{type: :string, description: "MIME type (e.g. image/jpeg)"}
      },
      required: ["token", "media_data", "media_type"]
    }

  def handler(input, _ctx \\ nil) do
    token = input[:token] || input["token"]
    media_data = input[:media_data] || input["media_data"]
    media_type = input[:media_type] || input["media_type"]

    url = "https://upload.twitter.com/1.1/media/upload.json"
    total_bytes = byte_size(media_data)

    headers = [{"Authorization", "Bearer #{token}"}]

    # 1. INIT
    init_form = [command: "INIT", total_bytes: total_bytes, media_type: media_type]
    case Req.post(url, form: init_form, headers: headers) do
      {:ok, %Req.Response{status: status, body: %{"media_id_string" => media_id}}} when status in 200..299 ->
        # 2. APPEND
        multipart = [
          {:command, "APPEND"},
          {:media_id, media_id},
          {:segment_index, "0"},
          {:media, media_data}
        ]
        case Req.post(url, multipart: multipart, headers: headers) do
          {:ok, %Req.Response{status: status2}} when status2 in 200..299 ->
            # 3. FINALIZE
            finalize_form = [command: "FINALIZE", media_id: media_id]
            case Req.post(url, form: finalize_form, headers: headers) do
              {:ok, %Req.Response{status: status3, body: %{"media_id_string" => final_media_id}}} when status3 in 200..299 ->
                {:ok, %{media_id: final_media_id}}
              {:ok, response} -> {:error, response.body}
              {:error, err} -> {:error, err}
            end
          {:ok, response} -> {:error, response.body}
          {:error, err} -> {:error, err}
        end
      {:ok, response} -> {:error, response.body}
      {:error, err} -> {:error, err}
    end
  end
end
