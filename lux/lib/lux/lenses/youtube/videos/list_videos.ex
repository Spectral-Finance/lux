defmodule Lux.Lenses.YouTube.Videos.ListVideos do
  @moduledoc "Lists YouTube videos with pagination and normalized metadata."

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Videos",
    description: "Lists YouTube videos using YouTube Data API v3 filters",
    url: "https://www.googleapis.com/youtube/v3/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        chart: %{type: :string, enum: ["mostPopular"]},
        part: %{type: :string},
        max_results: %{type: :integer, minimum: 1, maximum: 50},
        page_token: %{type: :string},
        region_code: %{type: :string}
      },
      required: ["chart"]
    }

  def before_focus(params) do
    params
    |> put_default(:part, "snippet,statistics")
    |> rename(:max_results, :maxResults)
    |> rename(:page_token, :pageToken)
    |> rename(:region_code, :regionCode)
  end

  def after_focus(%{"items" => items} = response) when is_list(items) do
    result = %{
      videos: Enum.map(items, &normalize_video/1)
    }

    result = maybe_put(result, :next_page_token, response["nextPageToken"])
    result = maybe_put(result, :page_info, normalize_page_info(response["pageInfo"]))
    {:ok, result}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(response), do: {:ok, response}

  defp normalize_video(video) do
    snippet = video["snippet"] || %{}
    statistics = video["statistics"] || %{}

    %{
      id: video["id"],
      title: snippet["title"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      published_at: snippet["publishedAt"],
      live_broadcast_content: snippet["liveBroadcastContent"],
      view_count: statistics["viewCount"],
      like_count: statistics["likeCount"],
      comment_count: statistics["commentCount"]
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
