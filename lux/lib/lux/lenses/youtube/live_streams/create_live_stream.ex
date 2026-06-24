defmodule Lux.Lenses.YouTube.LiveStreams.CreateLiveStream do
  @moduledoc """
  A lens for creating a live stream broadcast on YouTube.

  Creates a live stream resource that can be associated with a video.
  Supports both testing and production streams with configurable
  streaming parameters.

  ## Parameters

  - `title`: Stream title (required)
  - `description`: Stream description
  - `scheduled_start_time`: ISO 8601 start time
  - `scheduled_end_time`: ISO 8601 end time
  - `concurrent_viewers`: Expected concurrent viewers estimate
  - `format`: Stream format (standard, 360p, 480p, 720p, 1080p, 4K)
  - `projection`: Stream projection (rectangular, equirectangular360, cubemap)
  - `secret_key`: Secret key for stream authentication
  - `ingestion_type`: Type of ingestion (rtmp, dash, hls, smooth)
  - `definition`: Stream definition (standard, hd)
  - `closed_captions`: Whether closed captions are enabled

  ## Examples

      # Create a standard live stream
      iex> CreateLiveStream.focus(%{
      ...>   title: "My Live Stream",
      ...>   scheduled_start_time: "2026-07-01T12:00:00Z",
      ...>   scheduled_end_time: "2026-07-01T13:00:00Z"
      ...> })
      {:ok, %{id: "...", ingress_id: "...", stream_key: "..."}}

      # Create a testing stream
      iex> CreateLiveStream.focus(%{
      ...>   title: "Test Stream",
      ...>   format: "360p",
      ...>   secret_key: "my-secret"
      ...> })
      {:ok, %{id: "...", format: "360p", ...}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Create YouTube Live Stream",
    description: "Creates a live stream broadcast on YouTube",
    url: "#{YouTube.api_base_url()}/liveStreams",
    method: :post,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "Stream title (max 100 characters)",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "Stream description (max 5,000 characters)"
        },
        scheduled_start_time: %{
          type: :string,
          description: "ISO 8601 scheduled start time (e.g., '2026-07-01T12:00:00Z')"
        },
        scheduled_end_time: %{
          type: :string,
          description: "ISO 8601 scheduled end time (e.g., '2026-07-01T13:00:00Z')"
        },
        concurrent_viewers: %{
          type: :integer,
          description: "Estimated number of concurrent viewers"
        },
        format: %{
          type: :string,
          description: "Stream format quality",
          enum: ["standard", "360p", "480p", "720p", "1080p", "4K"],
          default: "standard"
        },
        projection: %{
          type: :string,
          description: "Stream projection type",
          enum: ["rectangular", "equirectangular360", "cubemap"],
          default: "rectangular"
        },
        secret_key: %{
          type: :string,
          description: "Secret key for stream authentication (used for testing)"
        },
        ingestion_type: %{
          type: :string,
          description: "Type of stream ingestion",
          enum: ["rtmp", "dash", "hls", "smooth"],
          default: "rtmp"
        },
        definition: %{
          type: :string,
          description: "Stream definition quality",
          enum: ["standard", "hd"],
          default: "standard"
        },
        closed_captions: %{
          type: :boolean,
          description: "Whether closed captions are enabled",
          default: false
        },
        default_audio_track: %{
          type: :string,
          description: "Default audio track type",
          enum: ["standard", "music"],
          default: "standard"
        },
        associated_video_id: %{
          type: :string,
          description: "Video ID to associate this stream with (for streaming uploads)"
        }
      },
      required: ["title"]
    }

  @impl true
  def before_focus(params) do
    snippet = build_snippet(params)
    content_details = build_content_details(params)
    status = build_status(params)

    body = %{
      snippet: snippet,
      contentDetails: content_details,
      status: status
    }

    %{url: "#{YouTube.api_base_url()}/liveStreams?part=snippet,contentDetails,status", json: body}
  end

  @doc """
  Transforms the YouTube API live stream creation response.
  """
  @impl true
  def after_focus(%{
    "id" => stream_id,
    "snippet" => snippet,
    "contentDetails" => content_details,
    "status" => status
  }) do
    Logger.info("Successfully created live stream: #{stream_id}")

    {:ok, %{
      id: stream_id,
      title: snippet["title"],
      scheduled_start_time: contentDetails = content_details["scheduledStartTime"],
      scheduled_end_time: content_details["scheduledEndTime"],
      ingestion_type: content_details["ingestionInfo"]["ingestionType"],
      stream_key: content_details["ingestionInfo"]["streamKey"],
      ingestion_address: content_details["ingestionInfo"]["ingestionAddress"],
      format: content_details["format"],
      definition: content_details["definition"],
      projection: content_details["projection"],
      secret_key: content_details["secretKey"],
      concurrent_viewers: status["concurrentViewerStats"]["estimatedConcurrentViews"],
      created_at: snippet["publishedAt"]
    }}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp build_snippet(params) do
    %{
      title: params[:title],
      description: Map.get(params, :description, ""),
      scheduledStartTime: Map.get(params, :scheduled_start_time),
      scheduledEndTime: Map.get(params, :scheduled_end_time)
    }
    |> Map.drop([{{:scheduledStartTime, nil}, nil}, {:scheduledEndTime, nil}])
  end

  defp build_content_details(params) do
    %{
      format: Map.get(params, :format, "standard"),
      projection: Map.get(params, :projection, "rectangular"),
      ingestionType: Map.get(params, :ingestion_type, "rtmp"),
      definition: Map.get(params, :definition, "standard"),
      secretKey: Map.get(params, :secret_key),
      allowClosedCaptions: Map.get(params, :closed_captions, false),
      defaultAudioTrack: Map.get(params, :default_audio_track, "standard")
    }
    |> Map.drop([{:secretKey, nil}])
  end

  defp build_status(params) do
    %{
      concurrentViewerStats: %{
        estimatedConcurrentViews: Map.get(params, :concurrent_viewers, 0)
      }
    }
  end
end
