defmodule Lux.Lenses.YouTube.LiveBroadcasts.GetLiveBroadcast do
  @moduledoc """
  A lens for retrieving YouTube live broadcast details and status.

  Returns broadcast metadata, status (testing/live/complete), and
  live streaming configuration.

  ## Authentication

  Requires OAuth2 token for accessing private broadcast data.

      config :lux, :api_keys, youtube_oauth_token: "your_oauth2_token"

  ## Examples

      iex> GetLiveBroadcast.focus(%{
      ...>   broadcast_id: "broadcast_id_here"
      ...> })
      {:ok, %{
        id: "broadcast_id_here",
        title: "My Live Stream",
        status: "live",
        scheduled_start_time: "2024-01-15T18:00:00.000Z",
        actual_start_time: "2024-01-15T18:00:05.000Z",
        concurrent_viewers: 1523,
        bound_stream_id: "stream_id_here"
      }}

      iex> GetLiveBroadcast.focus(%{
      ...>   mine: true
      ...> })
      {:ok, %{broadcasts: [...]}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Live Broadcast",
    description: "Retrieves live broadcast details, status, and streaming configuration",
    url: "https://www.googleapis.com/youtube/v3/liveBroadcasts",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.oauth_auth(),
    schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{
          type: :string,
          description: "The broadcast ID to retrieve"
        },
        mine: %{
          type: :boolean,
          description: "If true, retrieves all broadcasts owned by the authenticated user"
        },
        broadcast_status: %{
          type: :string,
          description: "Filter by status",
          enum: ["active", "all", "completed", "upcoming"]
        },
        max_results: %{
          type: :integer,
          description: "Maximum results when listing (1-50)",
          minimum: 1,
          maximum: 50
        }
      }
    }

  @impl true
  def before_focus(params) do
    query = %{"part" => "snippet,status,contentDetails,statistics"}

    query =
      cond do
        id = params["broadcast_id"] || params[:broadcast_id] ->
          Map.put(query, "id", id)
        params["mine"] || params[:mine] ->
          status = params["broadcast_status"] || params[:broadcast_status] || "all"
          query
          |> Map.put("mine", "true")
          |> Map.put("broadcastStatus", status)
          |> Map.put("maxResults", to_string(params["max_results"] || params[:max_results] || 20))
        true ->
          Map.put(query, "mine", "true")
      end

    {:ok, query}
  end

  @impl true
  def after_focus(%{"items" => [broadcast | _]} = data) when map_size(data) > 0 do
    {:ok, transform_broadcast(broadcast)}
  end

  def after_focus(%{"items" => broadcasts}) when length(broadcasts) > 1 do
    {:ok, %{broadcasts: Enum.map(broadcasts, &transform_broadcast/1)}}
  end

  def after_focus(%{"items" => []}) do
    {:error, %{message: "Broadcast not found"}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp transform_broadcast(broadcast) do
    snippet = broadcast["snippet"] || %{}
    status = broadcast["status"] || %{}
    content = broadcast["contentDetails"] || %{}
    stats = broadcast["statistics"] || %{}

    %{
      id: broadcast["id"],
      title: snippet["title"],
      description: snippet["description"],
      channel_id: snippet["channelId"],
      published_at: snippet["publishedAt"],
      scheduled_start_time: snippet["scheduledStartTime"],
      scheduled_end_time: snippet["scheduledEndTime"],
      actual_start_time: snippet["actualStartTime"],
      actual_end_time: snippet["actualEndTime"],
      thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]),
      life_cycle_status: status["lifeCycleStatus"],
      privacy_status: status["privacyStatus"],
      recording_status: status["recordingStatus"],
      bound_stream_id: content["boundStreamId"],
      bound_stream_last_update_time: content["boundStreamLastUpdateTimeMs"],
      enable_dvr: content["enableDvr"],
      enable_content_encryption: content["enableContentEncryption"],
      enable_embed: content["enableEmbed"],
      record_from_start: content["recordFromStart"],
      monitor_stream: get_in(content, ["monitorStream", "enableMonitorStream"]),
      concurrent_viewers: parse_int(stats["concurrentViewers"]),
      total_chat_count: parse_int(stats["totalChatCount"])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, ""} -> i
      _ -> nil
    end
  end
  defp parse_int(i) when is_integer(i), do: i
end
