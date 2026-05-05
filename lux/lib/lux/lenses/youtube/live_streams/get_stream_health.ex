defmodule Lux.Lenses.YouTube.LiveStreams.GetStreamHealth do
  @moduledoc "Fetches YouTube live stream health/status and CDN configuration."

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Live Stream Health",
    description: "Fetches live stream status, health and CDN settings from YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/liveStreams",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{id: %{type: :string, description: "Live stream ID"}},
      required: ["id"]
    }

  def before_focus(params), do: Map.put_new(params, :part, "snippet,status,cdn")

  def after_focus(%{"items" => [stream | _]}) do
    snippet = stream["snippet"] || %{}
    status = stream["status"] || %{}
    health = status["healthStatus"] || %{}
    cdn = stream["cdn"] || %{}

    {:ok,
     %{
       id: stream["id"],
       title: snippet["title"],
       stream_status: status["streamStatus"],
       health_status: health["status"],
       ingestion_type: cdn["ingestionType"],
       resolution: cdn["resolution"],
       frame_rate: cdn["frameRate"]
     }}
  end

  def after_focus(%{"items" => []}), do: {:error, "YouTube live stream not found"}
  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(response), do: {:ok, response}
end
