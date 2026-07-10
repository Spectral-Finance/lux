defmodule Lux.Lenses.YouTube.GetLiveStream do
  @moduledoc """
  A lens for fetching live broadcast information from the YouTube Live Streaming API.
  This lens provides a simple interface for getting live stream details with:
  - Broadcast status filter or broadcast ID
  - Configurable parts (snippet, status, contentDetails, etc.)
  - Direct YouTube API error propagation
  - Clean response structure

  ## Examples
      iex> GetLiveStream.focus(%{
      ...>   broadcast_status: "active"
      ...> })
      {:ok, [
        %{
          broadcast_id: "abc123",
          title: "Live Stream Title",
          description: "Stream description",
          scheduled_start_time: "2024-01-01T20:00:00Z",
          actual_start_time: "2024-01-01T20:01:00Z",
          life_cycle_status: "live",
          privacy_status: "public",
          stream_status: "active"
        }
      ]}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Live Stream",
    description: "Fetches live broadcast information from YouTube",
    url: "https://www.googleapis.com/youtube/v3/liveBroadcasts",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        broadcastStatus: %{
          type: :string,
          description: "Filter by broadcast status (active, all, completed, upcoming)"
        },
        id: %{
          type: :string,
          description: "The broadcast ID to fetch"
        },
        part: %{
          type: :string,
          description: "API resource parts to include",
          default: "snippet,status,contentDetails"
        }
      },
      required: []
    }

  def before_focus(params) do
    params
    |> Map.delete(:access_token)
    |> Map.delete("access_token")
    |> Map.delete(:plug)
    |> Map.delete("plug")
    |> Lux.Integrations.YouTube.Utils.to_youtube_query_params()
  end

  @doc """
  Transforms the YouTube API response into a simpler format.
  """
  @impl true
  def after_focus(%{"items" => items}) when is_list(items) do
    broadcasts = Enum.map(items, fn item ->
      snippet = item["snippet"] || %{}
      status = item["status"] || %{}
      content_details = item["contentDetails"] || %{}

      %{
        broadcast_id: item["id"],
        title: snippet["title"],
        description: snippet["description"],
        scheduled_start_time: snippet["scheduledStartTime"],
        actual_start_time: snippet["actualStartTime"],
        actual_end_time: snippet["actualEndTime"],
        life_cycle_status: status["lifeCycleStatus"],
        privacy_status: status["privacyStatus"],
        recording_status: status["recordingStatus"],
        bound_stream_id: content_details["boundStreamId"],
        stream_status: content_details["monitorStream"] && get_in(content_details, ["monitorStream", "enableMonitorStream"])
      }
    end)
    {:ok, broadcasts}
  end

  def after_focus(%{"error" => %{"message" => message}}) do
    {:error, %{"message" => message}}
  end
end
