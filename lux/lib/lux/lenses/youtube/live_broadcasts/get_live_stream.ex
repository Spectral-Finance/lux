defmodule Lux.Lenses.YouTube.LiveBroadcasts.GetLiveStream do
  @moduledoc """
  A lens for retrieving YouTube live stream details and health status.

  Returns stream configuration, ingestion settings (RTMP URL + stream key),
  and real-time health monitoring data.

  ## Authentication

  Requires OAuth2 token for accessing stream data.

      config :lux, :api_keys, youtube_oauth_token: "your_oauth2_token"

  ## Examples

      iex> GetLiveStream.focus(%{
      ...>   stream_id: "stream_id_here"
      ...> })
      {:ok, %{
        id: "stream_id_here",
        title: "My Stream",
        ingestion_type: "rtmp",
        ingestion_address: "rtmp://a.rtmp.youtube.com/live2",
        stream_key: "xxxx-xxxx-xxxx-xxxx",
        stream_status: "active",
        health_status: "good",
        last_ingestion_time: "2024-01-15T18:00:05.000Z"
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Live Stream",
    description: "Retrieves live stream details, ingestion settings, and health monitoring data",
    url: "https://www.googleapis.com/youtube/v3/liveStreams",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.oauth_auth(),
    schema: %{
      type: :object,
      properties: %{
        stream_id: %{
          type: :string,
          description: "The live stream ID to retrieve"
        },
        mine: %{
          type: :boolean,
          description: "If true, retrieves all streams owned by the authenticated user"
        },
        max_results: %{
          type: :integer,
          description: "Maximum results when listing",
          minimum: 1,
          maximum: 50
        }
      }
    }

  @impl true
  def before_focus(params) do
    query = %{"part" => "snippet,cdn,status,contentDetails"}

    query =
      cond do
        id = params["stream_id"] || params[:stream_id] ->
          Map.put(query, "id", id)
        params["mine"] || params[:mine] ->
          query
          |> Map.put("mine", "true")
          |> Map.put("maxResults", to_string(params["max_results"] || params[:max_results] || 20))
        true ->
          Map.put(query, "mine", "true")
      end

    {:ok, query}
  end

  @impl true
  def after_focus(%{"items" => [stream | _]}) do
    {:ok, transform_stream(stream)}
  end

  def after_focus(%{"items" => []}) do
    {:error, %{message: "Stream not found"}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp transform_stream(stream) do
    snippet = stream["snippet"] || %{}
    cdn = stream["cdn"] || %{}
    status = stream["status"] || %{}
    content = stream["contentDetails"] || %{}
    ingestion = cdn["ingestionInfo"] || %{}
    health = status["healthStatus"] || %{}

    %{
      id: stream["id"],
      title: snippet["title"],
      description: snippet["description"],
      channel_id: snippet["channelId"],
      published_at: snippet["publishedAt"],
      ingestion_type: cdn["ingestionType"],
      resolution: cdn["resolution"],
      frame_rate: cdn["frameRate"],
      ingestion_address: ingestion["ingestionAddress"],
      backup_ingestion_address: ingestion["backupIngestionAddress"],
      stream_key: ingestion["streamName"],
      rtmp_ingestion_address: ingestion["rtmpsIngestionAddress"],
      stream_status: status["streamStatus"],
      health_status: health["status"],
      last_ingestion_time: health["lastIngestionTime"],
      configuration_issues: health["configurationIssues"],
      is_reusable: content["isReusable"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
