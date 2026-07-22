defmodule Lux.Prisms.YouTube.UploadVideo do
  @moduledoc """
  A prism for uploading video files to YouTube using the resumable upload protocol.
  """

  use Lux.Prism,
    name: "Upload YouTube Video",
    description: "Uploads a video to YouTube using resumable chunk uploading",
    input_schema: %{
      type: :object,
      properties: %{
        file_path: %{
          type: :string,
          description: "Path to the local video file"
        },
        title: %{
          type: :string,
          description: "Title of the video",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "Description of the video"
        },
        privacy_status: %{
          type: :string,
          description: "Privacy status (public, private, unlisted)",
          enum: ["public", "private", "unlisted"],
          default: "private"
        },
        chunk_size: %{
          type: :integer,
          description: "Chunk size in bytes (must be a multiple of 262144 / 256KB)",
          default: 5242880 # 5 MB
        },
        access_token: %{
          type: :string,
          description: "OAuth2 access token"
        },
        dry_run: %{
          type: :boolean,
          description: "If true, mock the upload without hitting the YouTube API",
          default: false
        }
      },
      required: ["file_path", "title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        uploaded: %{
          type: :boolean,
          description: "Whether the video was successfully uploaded"
        },
        video_id: %{
          type: :string,
          description: "The YouTube video ID"
        },
        title: %{
          type: :string,
          description: "Title of the uploaded video"
        }
      },
      required: ["uploaded"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.Utils
  require Logger

  def handler(params, agent) do
    # Normalize inputs to allow both string and atom keys
    params = Utils.normalize_to_atoms(params)
    agent_name = agent[:name] || "Unknown Agent"

    file_path = Map.get(params, :file_path)
    title = Map.get(params, :title)
    description = Map.get(params, :description, "")
    privacy_status = Map.get(params, :privacy_status, "private")
    chunk_size = Map.get(params, :chunk_size, 5 * 1024 * 1024)
    access_token = Map.get(params, :access_token)
    plug = Map.get(params, :plug)

    dry_run = Map.get(params, :dry_run) || Application.get_env(:lux, :youtube_dry_run, false) || System.get_env("YOUTUBE_DRY_RUN") == "true"

    Logger.info("Agent #{agent_name} uploading video: #{title}")

    if dry_run do
      {:ok, %{uploaded: true, video_id: "mock_uploaded_video_id", title: title}}
    else
      # Check if file exists
      if File.exists?(file_path) do
        file_size = File.stat!(file_path).size
        mime_type = "video/*"

        # 1. Initiate resumable upload session
        metadata = %{
          snippet: %{
            title: title,
            description: description
          },
          status: %{
            privacyStatus: privacy_status
          }
        }

        # The initiation endpoint for resumable upload
        initiate_url = "https://www.googleapis.com/upload/youtube/v3/videos"

        case Client.request(:post, initiate_url, %{
          params: %{
            uploadType: "resumable",
            part: "snippet,status"
          },
          access_token: access_token,
          headers: [
            {"X-Upload-Content-Length", to_string(file_size)},
            {"X-Upload-Content-Type", mime_type}
          ],
          json: metadata,
          return_response: true,
          plug: plug
        }) do
          {:ok, response} ->
            # Google returns the upload URL in the Location header
            case get_header_value(response.headers, "location") do
              nil ->
                {:error, "Did not receive Location header for resumable upload"}

              upload_url ->
                # 2. Upload the file in chunks
                upload_in_chunks(upload_url, file_path, file_size, chunk_size, access_token, plug)
            end

          {:error, error} ->
            {:error, error}
        end
      else
        {:error, "File not found: #{file_path}"}
      end
    end
  end

  defp upload_in_chunks(upload_url, file_path, file_size, chunk_size, access_token, plug) do
    # Enforce chunk size is multiple of 256KB
    chunk_size = normalize_chunk_size(chunk_size)

    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        try do
          upload_chunk_loop(file, upload_url, file_size, chunk_size, 0, access_token, plug)
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, "Could not open file: #{inspect(reason)}"}
    end
  end

  defp upload_chunk_loop(file, upload_url, file_size, chunk_size, current_byte, access_token, plug) do
    case :file.pread(file, current_byte, chunk_size) do
      {:ok, data} ->
        data_len = byte_size(data)
        end_byte = current_byte + data_len - 1
        content_range = "bytes #{current_byte}-#{end_byte}/#{file_size}"

        headers = [
          {"Content-Length", to_string(data_len)},
          {"Content-Range", content_range},
          {"Content-Type", "video/*"}
        ]

        # Use PUT on the upload session URL
        case Client.request(:put, upload_url, %{
          access_token: access_token,
          headers: headers,
          # Pass binary data directly
          json: data, # Client handles binary/map
          return_response: true,
          plug: plug
        }) do
          {:ok, %{status: 308}} ->
            # Chunk uploaded successfully, but upload not finished yet
            upload_chunk_loop(file, upload_url, file_size, chunk_size, current_byte + data_len, access_token, plug)

          {:ok, %{status: status, body: body}} when status in [200, 201] ->
            # Finished!
            video_id = body["id"] || "mock_video_id"
            title = get_in(body, ["snippet", "title"]) || "Uploaded Video"
            {:ok, %{uploaded: true, video_id: video_id, title: title}}

          {:ok, response} ->
            {:error, "Unexpected response during chunk upload: status #{response.status}"}

          {:error, error} ->
            {:error, error}
        end

      :eof ->
        # We finished reading the file, should have completed on last chunk
        {:error, "Reached EOF without completing upload"}

      {:error, reason} ->
        {:error, "Error reading file: #{inspect(reason)}"}
    end
  end

  # Check upload status and resume
  def check_upload_status(upload_url, file_size, access_token, plug) do
    case Client.request(:put, upload_url, %{
      access_token: access_token,
      plug: plug,
      headers: [
        {"Content-Range", "bytes */#{file_size}"},
        {"Content-Type", "video/*"}
      ],
      return_response: true
    }) do
      {:ok, %{status: 308} = response} ->
        case get_header_value(response.headers, "range") do
          nil -> {:ok, 0}
          range_str ->
            case Regex.run(~r/bytes=\d+-(\d+)/, range_str) do
              [_, last_byte_str] ->
                {:ok, String.to_integer(last_byte_str) + 1}
              _ ->
                {:ok, 0}
            end
        end

      {:ok, %{status: status, body: body}} when status in [200, 201] ->
        video_id = body["id"] || "mock_video_id"
        title = get_in(body, ["snippet", "title"]) || "Uploaded Video"
        {:ok, :complete, %{uploaded: true, video_id: video_id, title: title}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_header_value(headers, name) do
    name_lower = String.downcase(name)
    list = Enum.to_list(headers)
    case Enum.find(list, fn {k, _} -> String.downcase(to_string(k)) == name_lower end) do
      {_, [val | _]} -> val
      {_, val} when is_binary(val) -> val
      _ -> nil
    end
  end

  defp normalize_chunk_size(size) do
    # Must be a multiple of 256KB
    block = 256 * 1024
    case rem(size, block) do
      0 -> size
      r -> size + (block - r)
    end
  end
end
