defmodule Lux.Lenses.YouTube.GetVideo do
  @moduledoc "Get YouTube video details."

  alias Lux.Integrations.YouTube.Client

  def focus(params, _opts \\ []) do
    video_id = params[:video_id] || params["video_id"]
    parts = params[:parts] || params["parts"] || "snippet,statistics,contentDetails,liveStreamingDetails"

    Client.request(:get, "/videos", %{
      params: %{part: parts, id: video_id},
      plug: params[:plug]
    })
    |> format_result()
  end

  defp format_result({:ok, %{"items" => [item | _]}}) do
    snippet = item["snippet"] || %{}
    stats = item["statistics"] || %{}
    content = item["contentDetails"] || %{}
    live = item["liveStreamingDetails"]

    result = %{
      id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      published_at: snippet["publishedAt"],
      tags: snippet["tags"] || [],
      category_id: snippet["categoryId"],
      duration: content["duration"],
      definition: content["definition"],
      view_count: stats["viewCount"],
      like_count: stats["likeCount"],
      comment_count: stats["commentCount"]
    }

    result = if live do
      Map.merge(result, %{
        live_broadcast: true,
        scheduled_start: live["scheduledStartTime"],
        actual_start: live["actualStartTime"],
        actual_end: live["actualEndTime"],
        concurrent_viewers: live["concurrentViewers"],
        live_chat_id: live["activeLiveChatId"]
      })
    else
      Map.put(result, :live_broadcast, false)
    end

    {:ok, result}
  end

  defp format_result({:ok, %{"items" => []}}), do: {:error, :not_found}
  defp format_result(error), do: error
end
