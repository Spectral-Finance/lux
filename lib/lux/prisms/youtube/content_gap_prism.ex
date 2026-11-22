defmodule Lux.Prisms.YouTube.ContentGapPrism do
  @moduledoc """
  A prism that finds content gaps in a YouTube niche
  (lux issue #78 — "YouTube Prism implementation", discovery intelligence).

  Pure and deterministic: given a list of competitor video items it extracts the
  keywords each competitor covers (title + tags), then reports the high-value
  topics that are *under-covered* — keywords appearing in few videos relative to
  the field, i.e. angles a creator could own. No network call is made here.

  ## Examples
      iex> ContentGapPrism.handler(%{videos: [
      ...>   %{snippet: %{title: "Sourdough basics", tags: ["bread", "starter"]}},
      ...>   %{snippet: %{title: "Sourdough bread", tags: ["bread"]}}
      ...> ]}, %{})
      {:ok, %{total_videos: 2, gaps: [{"starter", 1}, ...]}}
  """

  use Lux.Prism,
    name: "YouTube Content Gap",
    description:
      "Finds under-covered, high-value topics in a niche from competitor videos",
    input_schema: %{
      type: :object,
      properties: %{
        videos: %{type: :array, description: "Competitor video items", items: %{type: :object}},
        limit: %{type: :integer, description: "Max gaps to return (default 10)"}
      },
      required: ["videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_videos: %{type: :integer},
        gaps: %{type: :array, description: "[{keyword, coverage}] least-covered first"},
        covered_keywords: %{type: :integer}
      },
      required: ["total_videos", "gaps"]
    }

  alias Lux.Prisms.YouTube.{IntelUtil, Util}

  def handler(params, _agent) do
    videos = params |> Map.get(:videos, []) |> Enum.filter(&is_map/1)
    limit = params |> Map.get(:limit, 10) |> max(1)
    total = length(videos)

    # coverage[keyword] = number of distinct videos that mention it.
    coverage =
      Enum.reduce(videos, %{}, fn video, acc ->
        video
        |> keywords()
        |> Enum.uniq()
        |> Enum.reduce(acc, fn word, inner ->
          Map.update(inner, word, 1, &(&1 + 1))
        end)
      end)

    # A gap is a keyword covered by fewer than half the videos (under-served),
    # ranked by lowest coverage then alphabetically for determinism.
    gaps =
      coverage
      |> Enum.filter(fn {_word, count} -> total > 0 and count < total / 2 end)
      |> Enum.sort(fn {w1, c1}, {w2, c2} -> if c1 == c2, do: w1 < w2, else: c1 < c2 end)
      |> Enum.map(fn {word, count} -> {word, count} end)
      |> Enum.take(limit)

    result = %{
      total_videos: total,
      gaps: gaps,
      covered_keywords: map_size(coverage)
    }

    {:ok, result}
  end

  defp keywords(video) do
    snippet = IntelUtil.section(video, "snippet")
    title = IntelUtil.get_field(snippet, "title") || ""

    tags =
      case IntelUtil.get_field(snippet, "tags") do
        list when is_list(list) -> Enum.join(list, " ")
        _ -> ""
      end

    "#{title} #{tags}" |> Util.content_words()
  end
end