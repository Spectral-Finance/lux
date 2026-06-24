defmodule Lux.Lenses.YouTube.LiveStreams.ListBroadcasts do
  @moduledoc """
  A lens for listing and managing YouTube broadcast feed parameters.

  Provides access to broadcast settings including:
  - Live chat status and settings
  - Stream latency policy (low, balanced, standard)
  - Stream retention policy
  - Ad breaking configuration
  - Recording status
  - Broadcast associations (live stream + video)
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Broadcasts",
    description: "Lists broadcast feed parameters and settings for YouTube live streams",
    url: "#{YouTube.api_base_url()}/liveBroadcasts",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        live_stream_id: %{
          type: :string,
          description: "YouTube live stream resource ID to filter broadcasts"
        },
        broadcast_id: %{
          type: :string,
          description: "Specific broadcast ID to retrieve"
        },
        part: %{
          type: :string,
          description: "Comma-separated resource parts",
          default: "snippet,status,contentDetails"
        },
        broadcast_status: %{
          type: :string,
          description: "Filter by broadcast status",
          enum: ["all", "active", "completed", "rejected", "upcoming"]
        },
        on_behalf_of_content_owner: %{
          type: :string,
          description: "YouTube content owner ID for partner accounts"
        },
        mine: %{
          type: :boolean,
          description: "List broadcasts owned by the authenticated channel",
          default: false
        },
        max_results: %{
          type: :integer,
          description: "Max results to return (1-50)",
          minimum: 1,
          maximum: 50,
          default: 10
        },
        page_token: %{
          type: :string,
          description: "Pagination token from a previous response"
        }
      },
      required: []
    }

  @impl true
  def before_focus(params) do
    part = Map.get(params, :part, "snippet,status,contentDetails")
    max_results = Map.get(params, :max_results, 10)

    query_params = [{"part", part}, {"maxResults", max_results}]
    query_params = maybe_add(query_params, :live_stream_id, Map.get(params, :live_stream_id))
    query_params = maybe_add(query_params, :id, Map.get(params, :broadcast_id))
    query_params = maybe_add(query_params, :broadcastStatus, Map.get(params, :broadcast_status))
    query_params = maybe_add(query_params, :onBehalfOfContentOwner, Map.get(params, :on_behalf_of_content_owner))
    query_params = maybe_add(query_params, :mine, Map.get(params, :mine))
    query_params = maybe_add(query_params, :pageToken, Map.get(params, :page_token))

    %{url: "#{YouTube.api_base_url()}/liveBroadcasts?#{URI.encode_query(query_params)}"}
  end

  @doc """
  Transforms the broadcast response into a clean format.
  """
  @impl true
  def after_focus(%{"items" => items}) when is_list(items) do
    broadcasts = Enum.map(items, &transform_broadcast/1)
    result = %{broadcasts: broadcasts}
    {:ok, result}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp transform_broadcast(item) do
    snippet = item["snippet"] || %{}
    status = item["status"] || %{}
    content_details = item["contentDetails"] || %{}

    %{
      id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      scheduled_start_time: snippet["scheduledStartTime"],
      scheduled_end_time: snippet["scheduledEndTime"],
      published_at: snippet["publishedAt"],
      channel_id: snippet["channelId"],
      live_stream_id: snippet["liveStreamId"],
      communication_with_chatters_allowed: Map.get(status, "communicationWithChattersAllowed"),
      default_language: Map.get(status, "defaultLanguage"),
      default_audio_track: Map.get(status, "defaultAudioTrack"),
      life_cycle_status: Map.get(status, "lifeCycleStatus"),
      latency_policy: Map.get(content_details, "latencyPolicy"),
      retention_policy: Map.get(content_details, "retentionPolicy"),
      enable_chat: Map.get(content_details, "enableChat"),
      enable_dma: Map.get(content_details, "enableDma"),
      enable_ads: Map.get(content_details, "enableAds"),
      start_time_offset: Map.get(content_details, "startFrom"),
      end_time_offset: Map.get(content_details, "endFrom"),
      record_from_start: Map.get(content_details, "recordFromStart"),
      cut_from_start: Map.get(content_details, "cutFromStart"),
      cut_to_end: Map.get(content_details, "cutToEnd"),
      ad_break_wait_time: Map.get(content_details, "adBreakWaitTime"),
      friendly_name: Map.get(content_details, "friendlyName")
    }
  end

  defp maybe_add(params, _key, nil), do: params
  defp maybe_add(params, key, value) do
    params ++ [{Atom.to_string(key), to_string(value)}]
  end
end
