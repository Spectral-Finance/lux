defmodule Lux.Lenses.YouTube.LiveBroadcasts.ListBroadcasts do
  @moduledoc "Lists YouTube live broadcasts by lifecycle status."

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Live Broadcasts",
    description: "Lists live broadcasts by status with pagination",
    url: "https://www.googleapis.com/youtube/v3/liveBroadcasts",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        broadcast_status: %{type: :string, enum: ["active", "all", "completed", "upcoming"]},
        part: %{type: :string},
        max_results: %{type: :integer, minimum: 1, maximum: 50},
        page_token: %{type: :string}
      },
      required: ["broadcast_status"]
    }

  def before_focus(params) do
    params
    |> put_default(:part, "snippet,status,contentDetails")
    |> rename(:broadcast_status, :broadcastStatus)
    |> rename(:max_results, :maxResults)
    |> rename(:page_token, :pageToken)
  end

  def after_focus(%{"items" => items} = response) when is_list(items) do
    result = %{
      broadcasts: Enum.map(items, &normalize_broadcast/1)
    }

    result = maybe_put(result, :next_page_token, response["nextPageToken"])
    result = maybe_put(result, :page_info, normalize_page_info(response["pageInfo"]))
    {:ok, result}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(response), do: {:ok, response}

  defp normalize_broadcast(broadcast) do
    snippet = broadcast["snippet"] || %{}
    status = broadcast["status"] || %{}
    details = broadcast["contentDetails"] || %{}

    %{
      id: broadcast["id"],
      title: snippet["title"],
      channel_id: snippet["channelId"],
      scheduled_start_time: snippet["scheduledStartTime"],
      lifecycle_status: status["lifeCycleStatus"],
      privacy_status: status["privacyStatus"],
      bound_stream_id: details["boundStreamId"],
      live_chat_id: snippet["liveChatId"]
    }
  end

  defp normalize_page_info(nil), do: nil

  defp normalize_page_info(page_info) do
    %{
      total_results: page_info["totalResults"],
      results_per_page: page_info["resultsPerPage"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp put_default(params, key, value) do
    if Map.has_key?(params, key) or Map.has_key?(params, to_string(key)) do
      params
    else
      Map.put(params, key, value)
    end
  end

  defp rename(params, from, to) do
    string_from = to_string(from)

    cond do
      Map.has_key?(params, from) ->
        {value, params} = Map.pop(params, from)
        Map.put(params, to, value)

      Map.has_key?(params, string_from) ->
        {value, params} = Map.pop(params, string_from)
        Map.put(params, to, value)

      true ->
        params
    end
  end
end
