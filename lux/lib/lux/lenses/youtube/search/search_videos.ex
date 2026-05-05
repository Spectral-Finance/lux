defmodule Lux.Lenses.YouTube.Search.SearchVideos do
  @moduledoc "Searches YouTube videos via the Data API v3 search endpoint."

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Search YouTube Videos",
    description: "Searches YouTube videos by query using YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/search",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        query: %{type: :string},
        part: %{type: :string},
        max_results: %{type: :integer, minimum: 1, maximum: 50},
        page_token: %{type: :string},
        order: %{type: :string},
        published_after: %{type: :string}
      },
      required: ["query"]
    }

  def before_focus(params) do
    params
    |> put_default(:part, "snippet")
    |> put_default(:type, "video")
    |> rename(:query, :q)
    |> rename(:max_results, :maxResults)
    |> rename(:page_token, :pageToken)
    |> rename(:published_after, :publishedAfter)
  end

  def after_focus(%{"items" => items} = response) when is_list(items) do
    result = %{videos: Enum.map(items, &normalize_search_result/1)}
    result = maybe_put(result, :next_page_token, response["nextPageToken"])
    {:ok, result}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(response), do: {:ok, response}

  defp normalize_search_result(item) do
    id = item["id"] || %{}
    snippet = item["snippet"] || %{}

    %{
      video_id: id["videoId"],
      title: snippet["title"],
      description: snippet["description"],
      channel_id: snippet["channelId"],
      channel_title: snippet["channelTitle"],
      published_at: snippet["publishedAt"]
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
