defmodule Lux.Prisms.YouTube.Engagement do
  @moduledoc """
  A prism that computes the engagement rate of a set of videos (lux issue #73 —
  "YouTube Prism implementation").

  Pure and deterministic: given a list of video statistics maps (each with
  `view_count` / `like_count` / `comment_count`, as produced by
  `Lux.Prisms.YouTube.VideoStats` or a raw `videos.list` statistics block) it
  computes the per-video engagement rate `(likes + comments) / views * 100`,
  ranks the videos by that rate, and reports the top performer plus the set
  average. Zero-view videos are handled safely (rate 0.0, never a crash). No
  network call is made here.

  ## Examples
      iex> Engagement.handler(%{videos: [
      ...>   %{video_id: "a", view_count: 1000, like_count: 100, comment_count: 10},
      ...>   %{video_id: "b", view_count: 500, like_count: 10, comment_count: 0}
      ...> ]}, %{name: "Agent"})
      {:ok, %{count: 2, average_engagement_rate: 6.0, top: %{video_id: "a"}}}
  """

  use Lux.Prism,
    name: "YouTube Engagement",
    description:
      "Computes per-video engagement rate (likes + comments) / views, ranks videos, and reports the top performer and set average",
    input_schema: %{
      type: :object,
      properties: %{
        videos: %{
          type: :array,
          description:
            "List of video stats maps (view_count, like_count, comment_count, optional video_id)"
        }
      },
      required: ["videos"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        count: %{type: :integer, description: "Number of videos analysed"},
        average_engagement_rate: %{type: :number, description: "Mean engagement rate (%)"},
        total_views: %{type: :integer, description: "Sum of views across videos"},
        top: %{type: :object, description: "The highest-engagement video record"},
        videos: %{
          type: :array,
          description: "Per-video records with engagement_rate_percent"
        }
      },
      required: ["count", "average_engagement_rate", "videos"]
    }

  alias Lux.Prisms.YouTube.DataUtil

  def handler(params, _agent) do
    videos = Map.get(params, :videos, [])

    scored =
      videos
      |> Enum.map(&score/1)
      |> Enum.sort_by(& &1.engagement_rate_percent, :desc)

    rates = Enum.map(scored, & &1.engagement_rate_percent)
    total_views = scored |> Enum.map(& &1.view_count) |> Enum.sum()

    top = List.first(scored) || %{}

    result = %{
      count: length(scored),
      average_engagement_rate: DataUtil.round_to(DataUtil.mean(rates), 2),
      total_views: total_views,
      top: top,
      videos: scored
    }

    {:ok, result}
  end

  defp score(video) do
    views = DataUtil.to_int(Map.get(video, :view_count) || Map.get(video, :viewCount))
    likes = DataUtil.to_int(Map.get(video, :like_count) || Map.get(video, :likeCount))

    comments =
      DataUtil.to_int(Map.get(video, :comment_count) || Map.get(video, :commentCount))

    rate = DataUtil.safe_div(likes + comments, views) * 100

    %{
      video_id: Map.get(video, :video_id) || Map.get(video, :id, ""),
      view_count: views,
      like_count: likes,
      comment_count: comments,
      engagement_rate_percent: DataUtil.round_to(rate, 2)
    }
  end
end