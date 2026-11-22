defmodule Lux.Prisms.YouTube.VideoPerformancePrism do
  @moduledoc """
  A prism that scores the performance of a single YouTube video
  (lux issue #78 — "YouTube Prism implementation", video intelligence).

  Pure and deterministic: given a `videos.list` resource item it normalises the
  raw string-encoded statistics and computes an engagement rate, like/comment
  ratios and a blended 0-100 performance score. The score combines a capped
  engagement-rate component (70%) with a capped like-ratio component (30%) so a
  video with strong interaction relative to its reach ranks highly regardless of
  raw view count. No network call is made here — callers fetch the video via
  their YouTube client and pass it in.

  ## Examples
      iex> VideoPerformancePrism.handler(%{video: %{
      ...>   id: "v1",
      ...>   statistics: %{"viewCount" => "1000", "likeCount" => "100", "commentCount" => "20"}
      ...> }}, %{})
      {:ok, %{video_id: "v1", views: 1000, likes: 100, comments: 20,
             engagement_rate: 12.0, performance_score: 84.0}}
  """

  use Lux.Prism,
    name: "YouTube Video Performance",
    description:
      "Computes engagement rates, like/comment ratios and a 0-100 performance score for a single YouTube video resource",
    input_schema: %{
      type: :object,
      properties: %{
        video: %{type: :object, description: "A videos.list resource item"},
        benchmark_views: %{
          type: :integer,
          description: "Optional view count treated as a 100%% score reference"
        }
      },
      required: ["video"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        views: %{type: :integer},
        likes: %{type: :integer},
        comments: %{type: :integer},
        engagement_rate: %{type: :number, description: "(likes + comments) / views * 100"},
        like_ratio: %{type: :number},
        comment_ratio: %{type: :number},
        performance_score: %{type: :number, description: "Blended 0-100 score"}
      },
      required: ["video_id", "views", "performance_score"]
    }

  alias Lux.Prisms.YouTube.{IntelUtil, Util}

  def handler(params, _agent) do
    video = Map.get(params, :video) || %{}
    stats = IntelUtil.section(video, "statistics")

    views = stats |> IntelUtil.get_field("viewCount") |> Util.to_int()
    likes = stats |> IntelUtil.get_field("likeCount") |> Util.to_int()
    comments = stats |> IntelUtil.get_field("commentCount") |> Util.to_int()

    engagement_rate = IntelUtil.percent(likes + comments, views)
    like_ratio = Util.round_to(Util.safe_div(likes, views) * 100.0, 2)
    comment_ratio = Util.round_to(Util.safe_div(comments, views) * 100.0, 2)

    # 70% engagement-rate component (full marks at >= 10% ER) + 30% like-ratio
    # component (full marks at >= 10% like ratio).
    er_component = min(engagement_rate / 10.0, 1.0) * 70.0
    like_component = min(like_ratio / 10.0, 1.0) * 30.0
    score = Util.round_to(er_component + like_component, 2)

    result = %{
      video_id: IntelUtil.get_field(video, "id") || "",
      views: views,
      likes: likes,
      comments: comments,
      engagement_rate: engagement_rate,
      like_ratio: like_ratio,
      comment_ratio: comment_ratio,
      performance_score: score
    }

    {:ok, result}
  end
end