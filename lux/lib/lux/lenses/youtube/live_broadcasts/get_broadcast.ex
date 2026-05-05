defmodule Lux.Lenses.YouTube.LiveBroadcasts.GetBroadcast do
  @moduledoc "Fetches YouTube live broadcast lifecycle/status information."

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Live Broadcast",
    description: "Fetches a YouTube live broadcast by ID",
    url: "https://www.googleapis.com/youtube/v3/liveBroadcasts",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{id: %{type: :string, description: "Live broadcast ID"}},
      required: ["id"]
    }

  def before_focus(params), do: Map.put_new(params, :part, "snippet,status,contentDetails")

  def after_focus(%{"items" => [broadcast | _]}) do
    snippet = broadcast["snippet"] || %{}
    status = broadcast["status"] || %{}
    details = broadcast["contentDetails"] || %{}

    {:ok,
     %{
       id: broadcast["id"],
       title: snippet["title"],
       scheduled_start_time: snippet["scheduledStartTime"],
       lifecycle_status: status["lifeCycleStatus"],
       privacy_status: status["privacyStatus"],
       bound_stream_id: details["boundStreamId"],
       live_chat_id: snippet["liveChatId"]
     }}
  end

  def after_focus(%{"items" => []}), do: {:error, "YouTube live broadcast not found"}
  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(response), do: {:ok, response}
end
