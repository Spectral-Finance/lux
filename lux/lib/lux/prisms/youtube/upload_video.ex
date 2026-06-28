defmodule Lux.Prisms.YouTube.UploadVideo do
  @moduledoc """
  Uploads a video to YouTube. Supports resumable upload initialization.
  """
  use Lux.Prism,
    name: "YouTube Upload Video",
    description: "Initiates a resumable video upload session and uploads the video binary data.",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "The title of the video."
        },
        description: %{
          type: :string,
          description: "The description of the video."
        },
        tags: %{
          type: :array,
          items: %{type: :string},
          description: "Array of tags for the video."
        },
        privacy_status: %{
          type: :string,
          description: "Privacy status: 'public', 'unlisted', or 'private'."
        },
        video_data_base64: %{
          type: :string,
          description: "The raw video data encoded in base64."
        },
        dry_run: %{
          type: :boolean,
          description: "If true, simulates the API calls without mutation."
        }
      },
      required: ["title", "video_data_base64"]
    }

  alias Lux.Integrations.YouTube.VideoUpload
  alias Lux.Integrations.YouTube.Client

  @impl true
  def handler(params, _context) do
    title = Map.get(params, "title") || Map.get(params, :title)
    description = Map.get(params, "description") || Map.get(params, :description) || ""
    tags = Map.get(params, "tags") || Map.get(params, :tags) || []
    privacy_status = Map.get(params, "privacy_status") || Map.get(params, :privacy_status) || "private"
    video_data_base64 = Map.get(params, "video_data_base64") || Map.get(params, :video_data_base64)
    dry_run = Map.get_lazy(params, "dry_run", fn -> Map.get(params, :dry_run, true) end)

    config = %Client.Config{
      access_token: Application.get_env(:lux, :api_keys)[:youtube_access_token],
      dry_run: dry_run
    }

    metadata = %{
      snippet: %{
        title: title,
        description: description,
        tags: tags
      },
      status: %{
        privacyStatus: privacy_status
      }
    }

    case VideoUpload.initiate_upload_session(metadata, [], config) do
      {:ok, %{dry_run: true} = resp} ->
        {:ok, %{
          dry_run: true,
          message: "Would have initiated upload session and uploaded video bytes.",
          initiate_response: resp
        }}

      {:ok, upload_url} when is_binary(upload_url) ->
        with {:ok, video_data} <- Base.decode64(video_data_base64),
             {:ok, final_response} <- VideoUpload.upload_video_data(upload_url, video_data, config) do
          {:ok, %{
            status: "uploaded",
            video_id: get_in(final_response, ["id"]),
            details: final_response
          }}
        else
          :error -> {:error, "Upload failed: Invalid base64 video data"}
          {:error, reason} -> {:error, "Upload failed: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Session initiation failed: #{inspect(reason)}"}
    end
  end
end
