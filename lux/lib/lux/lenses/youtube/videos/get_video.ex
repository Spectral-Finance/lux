defmodule Lux.Lenses.YouTube.Videos.GetVideo do
  @moduledoc "Fetches and normalizes YouTube video metadata."

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Video",
    description: "Fetches video metadata/status/live-streaming details from YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "YouTube video ID"},
        part: %{type: :string, description: "Comma-separated YouTube resource parts"}
      },
      required: ["id"]
    }

  def before_focus(params) do
    Map.put_new(params, :part, "snippet,status,contentDetails,liveStreamingDetails")
  end

  def after_focus(%{"items" => [video | _]}) do
    snippet = video["snippet"] || %{}
    status = video["status"] || %{}
    live = video["liveStreamingDetails"] || %{}

    {:ok,
     %{
       id: video["id"],
       title: snippet["title"],
       channel_id: snippet["channelId"],
       privacy_status: status["privacyStatus"],
       live_broadcast_content: snippet["liveBroadcastContent"],
       active_live_chat_id: live["activeLiveChatId"],
       scheduled_start_time: live["scheduledStartTime"],
       actual_start_time: live["actualStartTime"],
       actual_end_time: live["actualEndTime"]
     }}
  end

  def after_focus(%{"items" => []}), do: {:error, "YouTube video not found"}
  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(response), do: {:ok, response}
end
