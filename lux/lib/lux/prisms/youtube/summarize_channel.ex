defmodule Lux.Prisms.YouTube.SummarizeChannel do
  @moduledoc """
  A prism that aggregates a list of per-video metric maps into channel-level
  statistics (lux issue #69 — "Analytics data collection and processing").

  Pure and deterministic: given a list of maps (each with at least `:views`,
  `:likes`, `:comments`, `:engagement_rate` — e.g. output of `AnalyzeVideo`),
  it returns totals, mean/median/stdev views, aggregate engagement rate, and
  the top/bottom videos by views.

  ## Examples
      iex> SummarizeChannel.handler(%{videos: [
      ...>   %{video_id: "a", views: 1000, likes: 50, comments: 10, engagement_rate: 0.06},
      ...>   %{video_id: "b", views: 500, likes: 10, comments: 2, engagement_rate: 0.024}
      ...> ]}, %{name: "Agent"})
      {:ok, %{count: 2, total_views: 1500, mean_views: 750.0}}
  """

  use Lux.Prism,
    name: "Summarize YouTube Channel",
    description: "Aggregates per-video metrics into channel-level statistics",
    input_schema: %{
      type: :object,
      properties: %{
        videos: %{
          type: :array,
          description: "List of per-video metric maps (views, likes, comments, engagement_rate)",
          items: %{type: :object}
        }
      },
      required: ["videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        count: %{type: :integer, description: "Number of videos"},
        total_views: %{type: :integer, description: "Sum of views"},
        mean_views: %{type: :number, description: "Mean views per video"},
        median_views: %{type: :number, description: "Median views"},
        stdev_views: %{type: :number, description: "Population stdev of views"},
        total_likes: %{type: :integer, description: "Sum of likes"},
        total_comments: %{type: :integer, description: "Sum of comments"},
        mean_engagement_rate: %{type: :number, description: "Mean of per-video engagement rates"},
        aggregate_engagement_rate: %{
          type: :number,
          description: "(total likes + comments) / total views"
        },
        top_video: %{type: :object, description: "Video with the most views"},
        bottom_video: %{type: :object, description: "Video with the fewest views"}
      },
      required: ["count"]
    }

  alias Lux.Prisms.YouTube.Util

  def handler(%{videos: videos}, _agent) when is_list(videos) do
    if videos == [] do
      {:ok, %{count: 0}}
    else
      views = Enum.map(videos, &int_field(&1, :views))
      likes = Enum.map(videos, &int_field(&1, :likes))
      comments = Enum.map(videos, &int_field(&1, :comments))
      eng_rates = Enum.map(videos, &num_field(&1, :engagement_rate))

      total_views = Enum.sum(views)
      total_likes = Enum.sum(likes)
      total_comments = Enum.sum(comments)

      top = Enum.max_by(videos, &int_field(&1, :views), fn -> %{} end)
      bottom = Enum.min_by(videos, &int_field(&1, :views), fn -> %{} end)

      result = %{
        count: length(videos),
        total_views: total_views,
        mean_views: round(Util.mean(views) * 100) / 100,
        median_views: Util.median(views),
        stdev_views: round(Util.pstdev(views) * 100) / 100,
        total_likes: total_likes,
        total_comments: total_comments,
        mean_engagement_rate: round(Util.mean(eng_rates) * 10_000) / 10_000,
        aggregate_engagement_rate:
          round(Util.safe_div(total_likes + total_comments, total_views) * 10_000) / 10_000,
        top_video: top,
        bottom_video: bottom
      }

      {:ok, result}
    end
  end

  def handler(_params, _agent), do: {:error, "Missing or invalid videos list"}

  defp int_field(map, key) do
    case Map.get(map, key, 0) do
      n when is_integer(n) -> n
      n when is_float(n) -> trunc(n)
      s when is_binary(s) -> Integer.parse(s) |> elem_or_zero()
      _ -> 0
    end
  end

  defp num_field(map, key) do
    case Map.get(map, key, 0.0) do
      n when is_number(n) -> n
      s when is_binary(s) -> Float.parse(s) |> elem_or_zero()
      _ -> 0.0
    end
  end

  defp elem_or_zero({val, _}), do: val
  defp elem_or_zero(:error), do: 0
end
