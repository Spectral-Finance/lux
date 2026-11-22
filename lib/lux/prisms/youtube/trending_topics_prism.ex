defmodule Lux.Prisms.YouTube.TrendingTopicsPrism do
  @moduledoc """
  A prism that extracts trending topics from a batch of YouTube videos
  (lux issue #78 — "YouTube Prism implementation", discovery intelligence).

  Pure and deterministic: given a list of `search.list` / `videos.list` items it
  tokenises each video's title + description + tags, weights each keyword by the
  video's view count, and returns the top topics ranked by aggregate weighted
  frequency. This surfaces what a niche is gravitating toward without any model
  call. No network call is made here.

  ## Examples
      iex> TrendingTopicsPrism.handler(%{videos: [
      ...>   %{snippet: %{title: "Sourdough basics"}, statistics: %{"viewCount" => "1000"}},
      ...>   %{snippet: %{title: "Sourdough starter"}, statistics: %{"viewCount" => "500"}}
      ...> ]}, %{})
      {:ok, %{total_videos: 2, topics: [{"sourdough", 1500.0}, ...]}}
  """

  use Lux.Prism,
    name: "YouTube Trending Topics",
    description:
      "Extracts view-weighted trending topics from a batch of YouTube videos",
    input_schema: %{
      type: :object,
      properties: %{
        videos: %{type: :array, description: "List of video/search items", items: %{type: :object}},
        limit: %{type: :integer, description: "Max topics to return (default 10)"}
      },
      required: ["videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_videos: %{type: :integer},
        topics: %{type: :array, description: "[{keyword, weighted_score}] sorted desc"},
        unique_keywords: %{type: :integer}
      },
      required: ["total_videos", "topics"]
    }

  alias Lux.Prisms.YouTube.{IntelUtil, Util}

  def handler(params, _agent) do
    videos = params |> Map.get(:videos, []) |> Enum.filter(&is_map/1)
    limit = params |> Map.get(:limit, 10) |> max(1)

    weights =
      Enum.reduce(videos, %{}, fn video, acc ->
        views = video |> IntelUtil.section("statistics") |> IntelUtil.get_field("viewCount") |> Util.to_int()
        # Weight = 1 + log10(views) so a 1M-view video outweighs a 1k-view one
        # without letting a single viral video completely dominate.
        weight = 1.0 + :math.log10(max(views, 1))
        text = video_text(video)

        text
        |> Util.content_words()
        |> Enum.uniq()
        |> Enum.reduce(acc, fn word, inner ->
          Map.update(inner, word, weight, &(&1 + weight))
        end)
      end)

    topics =
      weights
      |> Enum.sort(fn {w1, s1}, {w2, s2} -> if s1 == s2, do: w1 < w2, else: s1 > s2 end)
      |> Enum.map(fn {word, score} -> {word, Util.round_to(score, 2)} end)
      |> Enum.take(limit)

    result = %{
      total_videos: length(videos),
      topics: topics,
      unique_keywords: map_size(weights)
    }

    {:ok, result}
  end

  defp video_text(video) do
    snippet = IntelUtil.section(video, "snippet")
    title = IntelUtil.get_field(snippet, "title") || ""
    description = IntelUtil.get_field(snippet, "description") || ""

    tags =
      case IntelUtil.get_field(snippet, "tags") do
        list when is_list(list) -> Enum.join(list, " ")
        _ -> ""
      end

    "#{title} #{description} #{tags}"
  end
end