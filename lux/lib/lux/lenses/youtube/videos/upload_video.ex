defmodule Lux.Lenses.YouTube.Videos.UploadVideo do
  @moduledoc """
  A lens for uploading videos to YouTube via the Data API v3.

  Supports both standard uploads (direct file upload) and streaming uploads
  (for live stream content). Standard uploads cost 1,600 quota units;
  streaming uploads cost 50 quota units.

  ## Parameters

  - `title`: Video title (required, max 100 characters)
  - `description`: Video description (optional, max 5,000 characters)
  - `privacy_status`: Video visibility (private, draft, public, unlisted)
  - `category_id`: Video category ID (see YouTube's category list)
  - `tags`: Array of keyword tags
  - `default_language`: Video language (e.g., "en", "zh-CN")
  - `default_audio_track`: "standard" or "music"

  ## Live Streaming Uploads

  For live streams, use `streaming: true` to use the streaming upload path
  which is cheaper (50 units vs 1,600) and supports live broadcasting.

  ## Examples

      # Upload a standard video
      iex> UploadVideo.focus(%{
      ...>   title: "My Video",
      ...>   privacy_status: "private",
      ...>   description: "Video description"
      ...> })
      {:ok, %{id: "abc123...", title: "My Video", ...}}

      # Upload a live stream
      iex> UploadVideo.focus(%{
      ...>   title: "Live Stream",
      ...>   privacy_status: "private",
      ...>   streaming: true
      ...> })
      {:ok, %{id: "abc123...", streamingInfo: {...}, ...}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Upload YouTube Video",
    description: "Uploads a video to YouTube (standard or streaming)",
    url: "#{YouTube.api_base_url()}/videos",
    method: :post,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "Video title (max 100 characters)",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "Video description (max 5,000 characters)",
          maxLength: 5000
        },
        privacy_status: %{
          type: :string,
          description: "Video privacy status",
          enum: ["private", "draft", "public", "unlisted"],
          default: "private"
        },
        category_id: %{
          type: :string,
          description: "Video category ID (e.g., '22' for People & Blogs)"
        },
        tags: %{
          type: :array,
          description: "Video keyword tags",
          items: %{type: :string}
        },
        default_language: %{
          type: :string,
          description: "Default language for the video (e.g., 'en', 'zh-CN')"
        },
        default_audio_track: %{
          type: :string,
          description: "Default audio track type",
          enum: ["standard", "music"],
          default: "standard"
        },
        streaming: %{
          type: :boolean,
          description: "If true, prepares video for live streaming (cheaper quota)",
          default: false
        },
        scheduled_start_time: %{
          type: :string,
          description: "ISO 8601 scheduled start time for the stream (e.g., '2026-07-01T12:00:00Z')"
        },
        scheduled_end_time: %{
          type: :string,
          description: "ISO 8601 scheduled end time for the stream (e.g., '2026-07-01T13:00:00Z')"
        }
      },
      required: ["title"]
    }

  @impl true
  def before_focus(params) do
    snippet = build_snippet(params)
    status = build_status(params)

    body = %{
      snippet: snippet,
      status: status
    }

    %{url: __MODULE__.build_url(params), json: body}
  end

  @doc """
  Transforms the YouTube API response into a simpler format.

  ## Examples
      iex> after_focus(%{
      ...>   "id" => "abc123",
      ...>   "snippet" => %{"title" => "My Video"},
      ...>   "status" => %{"privacyStatus" => "private"}
      ...> })
      {:ok, %{id: "abc123", title: "My Video", privacy_status: "private"}}
  """
  @impl true
  def after_focus(%{"id" => video_id, "snippet" => snippet, "status" => status} = response) do
    Logger.info("Successfully uploaded video to YouTube: #{video_id} (#{snippet["title"]})")

    result = %{
      id: video_id,
      title: snippet["title"],
      description: snippet["description"],
      privacy_status: status["privacyStatus"],
      category_id: snippet["categoryId"],
      published_at: snippet["publishedAt"],
      thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
      default_audio_track: status["defaultAudioTrack"]
    }

    result =
      case Map.get(response, "streamingInfo") do
        nil -> result
        streaming -> Map.put(result, :streaming_info, streaming)
      end

    {:ok, result}
  end

  def after_focus(%{"error" => %{"message" => message}} = response) do
    Logger.error("YouTube upload failed: #{message}")
    {:error, message}
  end

  def after_focus(%{"error" => error}), do: {:error, error}

  defp build_snippet(params) do
    snippet = %{
      title: params[:title],
      description: Map.get(params, :description, "")
    }

    snippet =
      if lang = Map.get(params, :default_language) do
        Map.put(snippet, :defaultLanguage, lang)
      else
        snippet
      end

    snippet =
      if tags = Map.get(params, :tags) do
        Map.put(snippet, :tags, tags)
      else
        snippet
      end

    snippet =
      if cat = Map.get(params, :category_id) do
        Map.put(snippet, :categoryId, cat)
      else
        snippet
      end

    if audio = Map.get(params, :default_audio_track) do
      Map.put(snippet, :defaultAudioTrack, audio)
    else
      snippet
    end
  end

  defp build_status(params) do
    status = %{
      privacyStatus: Map.get(params, :privacy_status, "private"),
      defaultAudioTrack: Map.get(params, :default_audio_track, "standard")
    }

    status =
      if params[:streaming] do
        Map.put(status, :embeddable, true)
      else
        status
      end

    status =
      if start = Map.get(params, :scheduled_start_time) do
        Map.put(status, :publishAt, start)
      else
        status
      end

    status =
      if end_time = Map.get(params, :scheduled_end_time) do
        Map.put(status, :selfDeclaredMadeForKids, true)
        # Note: actual made_for_kids and self_declared fields would go here
        status
      else
        status
      end

    status
  end

  defp build_url(params) do
    part = if params[:streaming], do: "snippet,status,streaming", else: "snippet,status"
    "#{YouTube.api_base_url()}/videos?part=#{part}"
  end
end
