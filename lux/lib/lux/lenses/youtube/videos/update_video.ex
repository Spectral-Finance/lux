defmodule Lux.Lenses.YouTube.Videos.UpdateVideo do
  @moduledoc """
  A lens for updating video metadata on YouTube.

  Supports updating title, description, tags, category, privacy status,
  scheduled times, and thumbnail settings.

  ## Parameters

  - `video_id`: YouTube video ID (required, 11 characters)
  - `title`: New video title
  - `description`: New video description
  - `tags`: New keyword tags
  - `privacy_status`: New privacy status
  - `category_id`: New category ID
  - `scheduled_start_time`: New scheduled start (ISO 8601)
  - `scheduled_end_time`: New scheduled end (ISO 8601)
  - `default_language`: New default language

  ## Examples

      iex> UpdateVideo.focus(%{
      ...>   video_id: "dQw4w9WgXcQ",
      ...>   title: "Updated Title",
      ...>   description: "Updated description"
      ...> })
      {:ok, %{id: "dQw4w9WgXcQ", title: "Updated Title", ...}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Update YouTube Video",
    description: "Updates metadata for an existing YouTube video",
    url: "#{YouTube.api_base_url()}/videos",
    method: :put,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "YouTube video ID (11 characters)",
          pattern: "^[a-zA-Z0-9_-]{11}$"
        },
        title: %{
          type: :string,
          description: "New video title (max 100 characters)"
        },
        description: %{
          type: :string,
          description: "New video description (max 5,000 characters)"
        },
        tags: %{
          type: :array,
          description: "New keyword tags",
          items: %{type: :string}
        },
        privacy_status: %{
          type: :string,
          description: "New privacy status",
          enum: ["private", "draft", "public", "unlisted"]
        },
        category_id: %{
          type: :string,
          description: "New category ID"
        },
        scheduled_start_time: %{
          type: :string,
          description: "New scheduled start time (ISO 8601)"
        },
        scheduled_end_time: %{
          type: :string,
          description: "New scheduled end time (ISO 8601)"
        },
        default_language: %{
          type: :string,
          description: "New default language"
        },
        default_audio_track: %{
          type: :string,
          description: "New default audio track",
          enum: ["standard", "music"]
        }
      },
      required: ["video_id"]
    }

  @impl true
  def before_focus(params) do
    video_id = params[:video_id]

    snippet = build_snippet(params)
    status = build_status(params)

    body = %{
      id: video_id,
      snippet: snippet,
      status: status
    }

    part = build_part(params)
    %{url: "#{YouTube.api_base_url()}/videos?part=#{part}", json: body}
  end

  @doc """
  Transforms the YouTube API update response.
  """
  @impl true
  def after_focus(%{
    "id" => video_id,
    "snippet" => snippet,
    "status" => status
  }) do
    Logger.info("Successfully updated video: #{video_id}")

    {:ok, %{
      id: video_id,
      title: snippet["title"],
      description: snippet["description"],
      privacy_status: status["privacyStatus"],
      category_id: snippet["categoryId"],
      published_at: snippet["publishedAt"]
    }}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp build_snippet(params) do
    snippet = %{}

    snippet =
      if title = Map.get(params, :title) do
        Map.put(snippet, :title, title)
      else
        snippet
      end

    snippet =
      if desc = Map.get(params, :description) do
        Map.put(snippet, :description, desc)
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

    snippet =
      if lang = Map.get(params, :default_language) do
        Map.put(snippet, :defaultLanguage, lang)
      else
        snippet
      end

    snippet =
      if audio = Map.get(params, :default_audio_track) do
        Map.put(snippet, :defaultAudioTrack, audio)
      else
        snippet
      end

    snippet
  end

  defp build_status(params) do
    status = %{}

    status =
      if ps = Map.get(params, :privacy_status) do
        Map.put(status, :privacyStatus, ps)
      else
        status
      end

    status =
      if start = Map.get(params, :scheduled_start_time) do
        Map.put(status, :publishAt, start)
      else
        status
      end

    status
  end

  defp build_part(params) do
    parts = ["snippet", "status"]
    Enum.join(parts, ",")
  end
end
