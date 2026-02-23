defmodule Lux.Prisms.Twitter.Media.UploadMedia do
  @moduledoc """
  A prism for uploading media to Twitter using the chunked upload API.

  Supports uploading images (JPEG, PNG, GIF, WEBP) and videos (MP4, MOV).
  The prism handles the full chunked upload flow: INIT → APPEND → FINALIZE.

  After finalization, videos and GIFs require async processing. Check
  `GetUploadStatus` to poll for completion before attaching to tweets.

  ## Authentication

  Requires OAuth 1.0a User Context authentication. Configure in your application:

      config :lux, :api_keys,
        twitter_consumer_key: "your_consumer_key",
        twitter_consumer_secret: "your_consumer_secret",
        twitter_access_token: "your_access_token",
        twitter_access_token_secret: "your_access_token_secret"

  ## Media Constraints

  - **Images**: Max 5 MB (PNG, JPEG, WEBP), max 15 MB (GIF)
  - **Videos**: Max 512 MB (MP4, MOV), max 2 min 20 seconds
  - **Max 4 images** or **1 GIF/video** per tweet

  ## Examples

      iex> UploadMedia.handler(%{
      ...>   media_data: <<...binary...>>,
      ...>   media_type: "image/jpeg",
      ...>   alt_text: "A photo of the Eiffel Tower at sunset"
      ...> }, %{name: "Agent"})
      {:ok, %{
        media_id: "710511363345354753",
        media_key: "7_710511363345354753",
        media_type: "image/jpeg",
        size: 204800,
        requires_processing: false,
        expires_after_secs: 86400
      }}

      iex> UploadMedia.handler(%{
      ...>   media_data: <<...video_binary...>>,
      ...>   media_type: "video/mp4",
      ...>   media_category: "tweet_video"
      ...> }, %{name: "Agent"})
      {:ok, %{
        media_id: "710511363345354756",
        media_key: "7_710511363345354756",
        media_type: "video/mp4",
        requires_processing: true,
        processing_state: "pending"
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Prism,
    name: "Upload Twitter Media",
    description: "Uploads media (images, GIFs, videos) to Twitter using the chunked upload API",
    input_schema: %{
      type: :object,
      properties: %{
        media_data: %{
          type: :string,
          description: "Base64-encoded media data or raw binary content"
        },
        media_type: %{
          type: :string,
          description: "MIME type: 'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'video/mp4', 'video/quicktime'",
          enum: ["image/jpeg", "image/png", "image/gif", "image/webp", "video/mp4", "video/quicktime"]
        },
        media_category: %{
          type: :string,
          description: "Category: 'tweet_image', 'tweet_gif', 'tweet_video'. Defaults based on media_type.",
          enum: ["tweet_image", "tweet_gif", "tweet_video"]
        },
        alt_text: %{
          type: :string,
          description: "Accessibility alt text for images (recommended, max 1000 chars)"
        }
      },
      required: ["media_data", "media_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        media_id: %{type: :string, description: "Media ID to use when creating tweets"},
        media_key: %{type: :string},
        media_type: %{type: :string},
        size: %{type: :integer, description: "File size in bytes"},
        expires_after_secs: %{type: :integer},
        requires_processing: %{type: :boolean, description: "True for videos/GIFs requiring async processing"},
        processing_state: %{type: :string, description: "Initial processing state if requires_processing is true"}
      }
    }

  @chunk_size 5 * 1024 * 1024  # 5 MB chunks
  @upload_url "https://upload.twitter.com/1.1/media/upload.json"

  @impl true
  def handler(%{"media_data" => media_data, "media_type" => media_type} = params, _agent) do
    media_category = params["media_category"] || default_category(media_type)
    alt_text = params["alt_text"]

    media_bytes =
      if is_binary(media_data) and String.printable?(media_data) do
        case Base.decode64(media_data) do
          {:ok, decoded} -> decoded
          :error -> media_data
        end
      else
        media_data
      end

    total_bytes = byte_size(media_bytes)

    with {:ok, media_id} <- init_upload(media_type, media_category, total_bytes),
         :ok <- append_chunks(media_id, media_bytes, total_bytes),
         {:ok, result} <- finalize_upload(media_id) do
      result = Map.merge(result, %{
        media_type: media_type,
        size: total_bytes,
        requires_processing: requires_processing?(media_type)
      })

      result =
        if alt_text && Map.get(result, :media_id) do
          case set_alt_text(result.media_id, alt_text) do
            :ok -> Map.put(result, :alt_text_set, true)
            _ -> result
          end
        else
          result
        end

      {:ok, result}
    end
  end

  defp default_category("image/gif"), do: "tweet_gif"
  defp default_category("video/mp4"), do: "tweet_video"
  defp default_category("video/quicktime"), do: "tweet_video"
  defp default_category(_), do: "tweet_image"

  defp requires_processing?("image/gif"), do: true
  defp requires_processing?("video/mp4"), do: true
  defp requires_processing?("video/quicktime"), do: true
  defp requires_processing?(_), do: false

  defp init_upload(media_type, media_category, total_bytes) do
    url = @upload_url
    headers = [{"Content-Type", "application/json"}, {"Authorization", Twitter.build_oauth_header(:post, url, %{})}]

    body = %{
      "command" => "INIT",
      "media_type" => media_type,
      "media_category" => media_category,
      "total_bytes" => total_bytes
    }

    case Req.post(url,
           form: body,
           headers: headers,
           plug: Application.get_env(:lux, :req_options, [])[:plug]
         ) do
      {:ok, %{status: 202, body: %{"media_id_string" => media_id}}} ->
        {:ok, media_id}

      {:ok, %{status: status, body: body}} ->
        msg = get_in(body, ["errors", Access.at(0), "message"]) || "HTTP #{status}"
        {:error, "Upload INIT failed: #{msg}"}

      {:error, reason} ->
        {:error, "Upload INIT network error: #{inspect(reason)}"}
    end
  end

  defp append_chunks(media_id, media_bytes, total_bytes) do
    chunks = split_chunks(media_bytes, @chunk_size)

    chunks
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {chunk, index}, :ok ->
      case append_chunk(media_id, chunk, index) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, "Chunk #{index} failed: #{reason}"}}
      end
    end)
    |> case do
      :ok -> :ok
      {:error, _} = err -> err
    end

    _ = total_bytes
    :ok
  end

  defp split_chunks(data, chunk_size) do
    split_chunks(data, chunk_size, [])
  end

  defp split_chunks(<<>>, _size, acc), do: Enum.reverse(acc)
  defp split_chunks(data, size, acc) when byte_size(data) <= size, do: Enum.reverse([data | acc])
  defp split_chunks(data, size, acc) do
    <<chunk::binary-size(size), rest::binary>> = data
    split_chunks(rest, size, [chunk | acc])
  end

  defp append_chunk(media_id, chunk, segment_index) do
    url = @upload_url
    headers = [{"Content-Type", "application/json"}, {"Authorization", Twitter.build_oauth_header(:post, url, %{})}]

    body = %{
      "command" => "APPEND",
      "media_id" => media_id,
      "segment_index" => segment_index,
      "media_data" => Base.encode64(chunk)
    }

    case Req.post(url,
           form: body,
           headers: headers,
           plug: Application.get_env(:lux, :req_options, [])[:plug]
         ) do
      {:ok, %{status: 204}} -> :ok
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp finalize_upload(media_id) do
    url = @upload_url
    headers = [{"Content-Type", "application/json"}, {"Authorization", Twitter.build_oauth_header(:post, url, %{})}]

    body = %{
      "command" => "FINALIZE",
      "media_id" => media_id
    }

    case Req.post(url,
           form: body,
           headers: headers,
           plug: Application.get_env(:lux, :req_options, [])[:plug]
         ) do
      {:ok, %{status: status, body: body}} when status in [200, 201] ->
        processing = body["processing_info"] || %{}
        result = %{
          media_id: body["media_id_string"],
          media_key: body["media_key"],
          expires_after_secs: body["expires_after_secs"],
          processing_state: processing["state"]
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

        {:ok, result}

      {:ok, %{status: status, body: body}} ->
        msg = get_in(body, ["errors", Access.at(0), "message"]) || "HTTP #{status}"
        {:error, "Upload FINALIZE failed: #{msg}"}

      {:error, reason} ->
        {:error, "Upload FINALIZE network error: #{inspect(reason)}"}
    end
  end

  defp set_alt_text(media_id, alt_text) do
    url = "https://upload.twitter.com/1.1/media/metadata/create.json"
    headers = [{"Content-Type", "application/json"}, {"Authorization", Twitter.build_oauth_header(:post, url, %{})}]

    body = %{
      "media_id" => media_id,
      "alt_text" => %{"text" => String.slice(alt_text, 0, 1000)}
    }

    case Req.post(url,
           json: body,
           headers: headers,
           plug: Application.get_env(:lux, :req_options, [])[:plug]
         ) do
      {:ok, %{status: 204}} -> :ok
      _ -> :error
    end
  end
end
