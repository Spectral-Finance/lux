defmodule Lux.Integrations.YouTube.LiveStream do
  @moduledoc """
  Normalization and decision helpers for YouTube live broadcasts and streams.
  """

  def normalize_broadcast(%{"id" => id} = item) do
    snippet = item["snippet"] || %{}
    status = item["status"] || %{}
    details = item["contentDetails"] || %{}

    %{
      id: id,
      title: snippet["title"],
      description: snippet["description"],
      scheduled_start_time: snippet["scheduledStartTime"],
      actual_start_time: snippet["actualStartTime"],
      actual_end_time: snippet["actualEndTime"],
      live_chat_id: snippet["liveChatId"],
      privacy_status: status["privacyStatus"],
      lifecycle_status: status["lifeCycleStatus"],
      recording_status: status["recordingStatus"],
      bound_stream_id: details["boundStreamId"],
      monitor_stream_enabled: get_in(details, ["monitorStream", "enableMonitorStream"])
    }
  end

  def normalize_stream(%{"id" => id} = item) do
    snippet = item["snippet"] || %{}
    cdn = item["cdn"] || %{}
    status = item["status"] || %{}

    %{
      id: id,
      title: snippet["title"],
      description: snippet["description"],
      ingestion_type: cdn["ingestionType"],
      frame_rate: cdn["frameRate"],
      resolution: cdn["resolution"],
      stream_status: status["streamStatus"],
      health_status: get_in(status, ["healthStatus", "status"]),
      health_issues: get_in(status, ["healthStatus", "configurationIssues"]) || [],
      ready_for_live: ready_for_live?(status)
    }
  end

  def normalize_chat_message(%{"id" => id} = item) do
    snippet = item["snippet"] || %{}
    author = item["authorDetails"] || %{}

    %{
      id: id,
      live_chat_id: snippet["liveChatId"],
      published_at: snippet["publishedAt"],
      type: snippet["type"],
      message: get_in(snippet, ["textMessageDetails", "messageText"]),
      author_channel_id: author["channelId"],
      author_display_name: author["displayName"],
      author_is_chat_owner: author["isChatOwner"] || false,
      author_is_chat_moderator: author["isChatModerator"] || false
    }
  end

  def transition_plan(%{lifecycle_status: "testing"}, "live"), do: {:ok, ["live"]}
  def transition_plan(%{lifecycle_status: "ready"}, "testing"), do: {:ok, ["testing"]}
  def transition_plan(%{lifecycle_status: "ready"}, "live"), do: {:ok, ["testing", "live"]}
  def transition_plan(%{lifecycle_status: "live"}, "complete"), do: {:ok, ["complete"]}
  def transition_plan(%{lifecycle_status: target}, target), do: {:ok, []}

  def transition_plan(%{lifecycle_status: current}, target) do
    {:error, "Cannot transition broadcast from #{inspect(current)} to #{inspect(target)}"}
  end

  defp ready_for_live?(%{"streamStatus" => "active", "healthStatus" => %{"status" => health}})
       when health in ["good", "ok"],
       do: true

  defp ready_for_live?(_status), do: false
end
