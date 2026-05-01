defmodule Lux.Lenses.Youtube.Analytics.VideoPerformance do
  @moduledoc """
  A lens for analyzing individual video performance metrics.

  Tracks per-video metrics including:
  - View count and velocity
  - Like/dislike ratio
  - Comment count
  - Audience retention indicators

  ## Examples

      iex> VideoPerformance.handler(%{video_id: "abc123"}, %{name: "Agent"})
      {:ok, %{
        video_id: "abc123",
        views: 10000,
        likes: 500,
        comments: 50,
        like_ratio: 98.0
      }}
  """

  use Lux.Lens,
    name: "YouTube Video Performance",
    description: "Analyzes performance metrics for individual YouTube videos",
    input_schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "The YouTube video ID"
        },
        channel_id: %{
          type: :string,
          description: "Optional channel ID to filter videos"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of videos to return",
          default: 10
        }
      },
      required: ["video_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        views: %{type: :integer},
        likes: %{type: :integer},
        comments: %{type: :integer},
        like_ratio: %{type: :number}
      }
    }

  alias Lux.Integrations.Youtube.Client
  require Logger

  def handler(params, agent) do
    video_id = params[:video_id] || params["video_id"]
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching video performance for #{video_id}")

    case Client.request(:get, "/videos", %{params: %{part: "statistics", id: video_id}}) do
      {:ok, %{"items" => [video | _]}} ->
        stats = video["statistics"] || %{}
        metrics = %{
          video_id: video_id,
          views: String.to_integer(stats["viewCount"] || "0"),
          likes: String.to_integer(stats["likeCount"] || "0"),
          comments: String.to_integer(stats["commentCount"] || "0"),
          like_ratio: calculate_like_ratio(stats)
        }
        {:ok, metrics}

      {:ok, %{"items" => []}} ->
        {:error, "Video not found: #{video_id}"}

      error ->
        Logger.error("Failed to fetch video performance: #{inspect(error)}")
        error
    end
  end

  defp calculate_like_ratio(%{"likeCount" => likes, "dislikeCount" => dislikes}) do
    likes_int = String.to_integer(likes || "0")
    dislikes_int = String.to_integer(dislikes || "0")
    total = likes_int + dislikes_int
    if total > 0, do: Float.round(likes_int / total * 100, 1), else: 100.0
  end
  defp calculate_like_ratio(%{"likeCount" => likes}) do
    likes_int = String.to_integer(likes || "0")
    if likes_int > 0, do: 100.0, else: 0.0
  end
  defp calculate_like_ratio(_), do: 0.0
end
