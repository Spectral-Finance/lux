defmodule Lux.Prisms.YouTube.CreateBroadcast do
  @moduledoc """
  A prism for creating a new YouTube live broadcast.

  Creates a scheduled broadcast with the specified title, start time,
  and privacy settings. After creation, bind a live stream using
  TransitionBroadcast to go live.

  ## Authentication

  Requires OAuth2 token with `youtube` scope.

      config :lux, :api_keys, youtube_oauth_token: "your_oauth2_token"

  ## Examples

      iex> CreateBroadcast.handler(%{
      ...>   title: "My Live Stream",
      ...>   scheduled_start_time: "2024-02-01T18:00:00.000Z",
      ...>   privacy_status: "public",
      ...>   description: "Join us live!"
      ...> }, %{name: "Agent"})
      {:ok, %{
        broadcast_id: "newBroadcastId",
        title: "My Live Stream",
        status: "created",
        live_chat_id: "chatId...",
        scheduled_start_time: "2024-02-01T18:00:00.000Z"
      }}
  """

  use Lux.Prism,
    name: "Create YouTube Broadcast",
    description: "Creates a new YouTube live broadcast with scheduling and privacy settings",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "The broadcast title (max 100 characters)",
          maxLength: 100
        },
        scheduled_start_time: %{
          type: :string,
          description: "ISO 8601 datetime for when the broadcast is scheduled to start"
        },
        description: %{
          type: :string,
          description: "Broadcast description (max 5000 characters)",
          maxLength: 5000
        },
        privacy_status: %{
          type: :string,
          description: "Privacy setting for the broadcast",
          enum: ["public", "private", "unlisted"],
          default: "public"
        },
        enable_dvr: %{
          type: :boolean,
          description: "Enable DVR (rewind) for viewers",
          default: true
        },
        enable_content_encryption: %{
          type: :boolean,
          description: "Enable content encryption",
          default: false
        },
        enable_embed: %{
          type: :boolean,
          description: "Allow embedding",
          default: true
        },
        record_from_start: %{
          type: :boolean,
          description: "Record from the start of the broadcast",
          default: true
        }
      },
      required: ["title", "scheduled_start_time"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string},
        title: %{type: :string},
        status: %{type: :string},
        live_chat_id: %{type: :string},
        scheduled_start_time: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube

  @broadcast_url "https://www.googleapis.com/youtube/v3/liveBroadcasts"

  @impl true
  def handler(params, _agent_ctx) do
    title = params["title"] || params[:title]
    start_time = params["scheduled_start_time"] || params[:scheduled_start_time]
    description = params["description"] || params[:description] || ""
    privacy = params["privacy_status"] || params[:privacy_status] || "public"

    body = %{
      snippet: %{
        title: title,
        scheduledStartTime: start_time,
        description: description
      },
      status: %{
        privacyStatus: privacy,
        selfDeclaredMadeForKids: false
      },
      contentDetails: %{
        enableDvr: params["enable_dvr"] != false && params[:enable_dvr] != false,
        enableContentEncryption: params["enable_content_encryption"] == true || params[:enable_content_encryption] == true,
        enableEmbed: params["enable_embed"] != false && params[:enable_embed] != false,
        recordFromStart: params["record_from_start"] != false && params[:record_from_start] != false,
        monitorStream: %{enableMonitorStream: true, broadcastStreamDelayMs: 0}
      }
    }

    oauth_token = Application.get_env(:lux, :api_keys)[:youtube_oauth_token]

    headers = YouTube.headers() ++ [{"Authorization", "Bearer #{oauth_token}"}]

    case Req.post(@broadcast_url,
      json: body,
      params: %{"part" => "snippet,status,contentDetails"},
      headers: headers
    ) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        snippet = resp_body["snippet"] || %{}
        content = resp_body["contentDetails"] || %{}

        {:ok, %{
          broadcast_id: resp_body["id"],
          title: snippet["title"],
          status: "created",
          live_chat_id: snippet["liveChatId"],
          scheduled_start_time: snippet["scheduledStartTime"],
          bound_stream_id: content["boundStreamId"]
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()}

      {:ok, %{body: %{"error" => %{"message" => msg}}}} ->
        {:error, %{message: msg}}

      {:error, reason} ->
        {:error, %{message: inspect(reason)}}
    end
  end
end
