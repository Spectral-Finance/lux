defmodule Lux.Prisms.Twitter.Media.UploadMedia do
  @moduledoc """
  A prism for uploading media to Twitter via the media upload API.

  Supports:
  - Image uploads (JPEG, PNG, GIF, WEBP)
  - Video uploads (MP4)
  - Chunked uploads for large files

  ## Examples

      iex> UploadMedia.handler(%{file_path: "/path/to/image.jpg"}, %{name: "Agent"})
      {:ok, %{
        uploaded: true,
        media_id: "1234567890",
        media_id_string: "1234567890"
      }}

      iex> UploadMedia.handler(%{
      ...>   file_path: "/path/to/video.mp4",
      ...>   media_type: "video/mp4"
      ...> }, %{name: "Agent"})
      {:ok, %{uploaded: true, media_id: "..."}}
  """

  use Lux.Prism,
    name: "Upload Media",
    description: "Uploads media (images, videos) to Twitter for use in tweets",
    input_schema: %{
      type: :object,
      properties: %{
        file_path: %{
          type: :string,
          description: "Path to the media file to upload"
        },
        media_type: %{
          type: :string,
          description: "MIME type of the media (e.g., image/jpeg, video/mp4)",
          enum: ["image/jpeg", "image/png", "image/gif", "image/webp", "video/mp4"]
        },
        alt_text: %{
          type: :string,
          description: "Alt text for accessibility",
          maxLength: 1000
        }
      },
      required: ["file_path"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        uploaded: %{
          type: :boolean,
          description: "Whether the media was successfully uploaded"
        },
        media_id: %{
          type: :integer,
          description: "The numeric media ID"
        },
        media_id_string: %{
          type: :string,
          description: "The string media ID (use this for tweet creation)"
        }
      },
      required: ["uploaded"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles the request to upload media.
  """
  def handler(params, agent) do
    with {:ok, file_path} <- validate_param(params, :file_path),
         :ok <- validate_file(file_path) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} uploading media: #{file_path}")

      media_type = params[:media_type] || params["media_type"] || detect_media_type(file_path)
      file_size = File.stat!(file_path).size

      cond do
        video?(media_type) or file_size > 5_000_000 ->
          upload_chunked(file_path, media_type, params)

        true ->
          upload_simple(file_path, media_type, params)
      end
    end
  end

  defp upload_simple(file_path, media_type, params) do
    fields = [
      {"media", {:file, file_path}},
      {"media_type", media_type},
      {"media_category", "tweet_image"}
    ]

    case Client.multipart_request("/media/upload.json", fields) do
      {:ok, %{"media_id_string" => media_id_string} = response} ->
        media_id = response["media_id"]
        maybe_set_alt_text(media_id_string, params)
        Logger.info("Successfully uploaded media #{media_id_string}")
        {:ok, %{uploaded: true, media_id: media_id, media_id_string: media_id_string}}

      {:ok, response} ->
        Logger.info("Media upload response: #{inspect(response)}")
        {:ok, Map.put(response, :uploaded, true)}

      {:error, reason} ->
        Logger.error("Failed to upload media: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp upload_chunked(file_path, media_type, params) do
    file_data = File.read!(file_path)
    total_bytes = byte_size(file_data)
    chunk_size = 5_000_000 # 5MB chunks
    total_segments = ceil(total_bytes / chunk_size)

    Logger.info("Uploading #{total_bytes} bytes in #{total_segments} segments")

    # INIT phase
    init_fields = [
      {"command", "INIT"},
      {"total_bytes", to_string(total_bytes)},
      {"media_type", media_type},
      {"media_category", if(video?(media_type), do: "tweet_video", else: "tweet_gif")}
    ]

    with {:ok, %{"media_id_string" => media_id}} <-
           Client.multipart_request("/media/upload.json", init_fields) do
      # APPEND phase
      append_result =
        Enum.reduce_while(0..(total_segments - 1), :ok, fn segment_index, acc ->
          offset = segment_index * chunk_size
          chunk_size_actual = min(chunk_size, total_bytes - offset)
          chunk = binary_part(file_data, offset, chunk_size_actual)

          # Write chunk to temp file
          temp_path = Path.join(System.tmp_dir(), "twitter_upload_chunk_#{segment_index}.bin")
          File.write!(temp_path, chunk)

          fields = [
            {"command", "APPEND"},
            {"media_id", media_id},
            {"segment_index", to_string(segment_index)},
            {"media", {:file, temp_path}}
          ]

          case Client.multipart_request("/media/upload.json", fields) do
            {:ok, _} ->
              File.rm(temp_path)
              {:cont, :ok}

            {:error, reason} ->
              File.rm(temp_path)
              {:halt, {:error, reason}}
          end
        end)

      case append_result do
        :ok ->
          # FINALIZE phase
          finalize_fields = [
            {"command", "FINALIZE"},
            {"media_id", media_id}
          ]

          case Client.multipart_request("/media/upload.json", finalize_fields) do
            {:ok, response} ->
              maybe_set_alt_text(media_id, params)
              Logger.info("Successfully uploaded chunked media #{media_id}")
              {:ok, %{uploaded: true, media_id: response["media_id"], media_id_string: media_id}}

            {:error, reason} ->
              Logger.error("Failed to finalize media upload: #{inspect(reason)}")
              {:error, reason}
          end

        {:error, reason} ->
          Logger.error("Failed during chunked upload: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to initialize chunked upload: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp maybe_set_alt_text(media_id, %{alt_text: text}) when is_binary(text) and text != "" do
    fields = [
      {"command", "METADATA"},
      {"media_id", media_id},
      {"alt_text", %{"text" => text} |> Jason.encode!()}
    ]

    Client.multipart_request("/media/metadata/create.json", fields)
  end

  defp maybe_set_alt_text(_media_id, _params), do: :ok

  defp video?("video/" <> _), do: true
  defp video?(_), do: false

  defp detect_media_type(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".mp4" -> "video/mp4"
      _ -> "application/octet-stream"
    end
  end

  defp validate_file(file_path) do
    if File.exists?(file_path) do
      :ok
    else
      {:error, "File not found: #{file_path}"}
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
