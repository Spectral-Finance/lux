defmodule Lux.Prisms.YouTube.StartLiveBroadcast do
  @moduledoc """
  A prism for creating and starting a live broadcast on YouTube.

  This prism provides a simple interface for starting YouTube live broadcasts with:
  - Required parameters (title, scheduled_start_time)
  - Optional parameters (description, privacy_status)
  - Creates both a live broadcast and binds a live stream
  - Direct YouTube API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> StartLiveBroadcast.handler(%{
      ...>   title: "My Live Stream",
      ...>   scheduled_start_time: "2024-01-01T20:00:00Z",
      ...>   privacy_status: "public"
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        broadcast_id: "abc123",
        title: "My Live Stream",
        life_cycle_status: "ready",
        privacy_status: "public"
      }}
  """

  use Lux.Prism,
    name: "Start YouTube Live Broadcast",
    description: "Creates and configures a new YouTube live broadcast",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "The title of the live broadcast",
          minLength: 1,
          maxLength: 100
        },
        description: %{
          type: :string,
          description: "The description of the live broadcast"
        },
        scheduled_start_time: %{
          type: :string,
          description: "ISO 8601 datetime for the scheduled start time",
          format: "date-time"
        },
        privacy_status: %{
          type: :string,
          description: "Privacy status (public, private, unlisted)",
          enum: ["public", "private", "unlisted"],
          default: "private"
        },
        stream_title: %{
          type: :string,
          description: "Title for the associated live stream"
        },
        resolution: %{
          type: :string,
          description: "Stream resolution (1080p, 720p, 480p, 360p, 240p)",
          default: "1080p"
        },
        frame_rate: %{
          type: :string,
          description: "Stream frame rate (30fps, 60fps)",
          default: "30fps"
        },
        ingestion_type: %{
          type: :string,
          description: "Ingestion type (rtmp, dash, webrtc, hls)",
          default: "rtmp"
        }
      },
      required: ["title", "scheduled_start_time"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the broadcast was successfully created"
        },
        broadcast_id: %{
          type: :string,
          description: "The ID of the created broadcast"
        },
        title: %{
          type: :string,
          description: "The title of the broadcast"
        },
        life_cycle_status: %{
          type: :string,
          description: "Current lifecycle status of the broadcast"
        },
        privacy_status: %{
          type: :string,
          description: "Privacy status of the broadcast"
        },
        stream_id: %{
          type: :string,
          description: "The ID of the associated live stream (if created)"
        },
        ingestion_address: %{
          type: :string,
          description: "The RTMP ingestion URL for the stream (if created)"
        },
        stream_name: %{
          type: :string,
          description: "The stream key/name for the stream (if created)"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.YouTube.Client
  require Logger

  @doc """
  Handles the request to create a live broadcast on YouTube.

  Creates a broadcast and optionally a bound live stream.

  Returns {:ok, %{created: true, broadcast_id: id, ...}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    params = Lux.Integrations.YouTube.Utils.normalize_to_atoms(params)
    with {:ok, title} <- validate_param(params, :title),
         {:ok, scheduled_start_time} <- validate_param(params, :scheduled_start_time) do
      agent_name = agent[:name] || "Unknown Agent"
      description = Map.get(params, :description, "")
      privacy_status = Map.get(params, :privacy_status, "private")
      access_token = Map.get(params, :access_token)
      plug = Map.get(params, :plug)
      dry_run = Map.get(params, :dry_run)

      Logger.info("Agent #{agent_name} creating YouTube live broadcast: #{title}")

      # Step 1: Create the broadcast
      case create_broadcast(title, description, scheduled_start_time, privacy_status, access_token, plug, dry_run) do
        {:ok, broadcast_result} ->
          # Step 2: Create a live stream and bind it (optional)
          stream_title = Map.get(params, :stream_title, "#{title} - Stream")
          resolution = Map.get(params, :resolution, "1080p")
          frame_rate = Map.get(params, :frame_rate, "30fps")
          ingestion_type = Map.get(params, :ingestion_type, "rtmp")

          case create_and_bind_stream(broadcast_result.broadcast_id, stream_title, resolution, frame_rate, ingestion_type, access_token, plug, dry_run) do
            {:ok, stream_result} ->
              {:ok, Map.merge(broadcast_result, stream_result)}

            {:error, error} ->
              # Propagate the binding/stream creation error instead of ignoring it
              Logger.error("Failed to create and bind stream: #{inspect(error)}")
              {:error, error}
          end

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp create_broadcast(title, description, scheduled_start_time, privacy_status, access_token, plug, dry_run) do
    case Client.request(:post, "/liveBroadcasts", %{
      params: %{part: "snippet,status,contentDetails"},
      access_token: access_token,
      plug: plug,
      dry_run: dry_run,
      json: %{
        snippet: %{
          title: title,
          description: description,
          scheduledStartTime: scheduled_start_time
        },
        status: %{
          privacyStatus: privacy_status,
          selfDeclaredMadeForKids: false
        },
        contentDetails: %{
          enableAutoStart: false,
          enableAutoStop: true,
          enableDvr: true,
          enableContentEncryption: false,
          enableEmbed: true,
          recordFromStart: true
        }
      }
    }) do
      {:ok, %{"id" => broadcast_id, "snippet" => %{"title" => title}, "status" => %{"lifeCycleStatus" => lcs, "privacyStatus" => ps}}} ->
        Logger.info("Successfully created broadcast #{broadcast_id}")
        {:ok, %{created: true, broadcast_id: broadcast_id, title: title, life_cycle_status: lcs, privacy_status: ps}}

      {:error, {status, message}} ->
        error = {status, message}
        Logger.error("Failed to create broadcast: #{inspect(error)}")
        {:error, error}

      {:error, error} ->
        Logger.error("Failed to create broadcast: #{inspect(error)}")
        {:error, error}
    end
  end

  defp create_and_bind_stream(broadcast_id, stream_title, resolution, frame_rate, ingestion_type, access_token, plug, dry_run) do
    # Create the live stream
    case Client.request(:post, "/liveStreams", %{
      params: %{part: "snippet,cdn,status"},
      access_token: access_token,
      plug: plug,
      dry_run: dry_run,
      json: %{
        snippet: %{
          title: stream_title
        },
        cdn: %{
          frameRate: frame_rate,
          ingestionType: ingestion_type,
          resolution: resolution
        }
      }
    }) do
      {:ok, %{"id" => stream_id, "cdn" => %{"ingestionInfo" => ingestion_info}}} ->
        # Bind the stream to the broadcast
        case Client.request(:post, "/liveBroadcasts/bind", %{
          params: %{
            part: "id,contentDetails",
            id: broadcast_id,
            streamId: stream_id
          },
          access_token: access_token,
          plug: plug,
          dry_run: dry_run
        }) do
          {:ok, _bind_res} ->
            {:ok, %{
              stream_id: stream_id,
              ingestion_address: ingestion_info["ingestionAddress"],
              stream_name: ingestion_info["streamName"]
            }}
          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
