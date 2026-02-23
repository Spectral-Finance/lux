defmodule Lux.Prisms.YouTube.OptimizeEndScreens do
  @moduledoc """
  A prism for optimizing YouTube end screen layouts to maximize conversions.

  Analyzes the video duration, channel context, and top-performing content
  to generate an optimized end screen configuration. Returns the recommended
  elements (subscribe button, latest video card, best-for-viewer card,
  featured playlist), precise timing, screen positions, and an expected
  click-through rate (CTR) boost estimate.

  YouTube end screens appear during the last 5-20 seconds of a video
  and support up to 4 interactive elements.

  ## Examples

      iex> OptimizeEndScreens.handler(%{
      ...>   "video_id" => "dQw4w9WgXcQ",
      ...>   "video_duration_seconds" => 213,
      ...>   "channel_id" => "UCxxxxxx",
      ...>   "top_performing_videos" => [
      ...>     %{"id" => "abc123", "title" => "Top Tutorial"}
      ...>   ]
      ...> }, %{})
      {:ok, %{
        video_id: "dQw4w9WgXcQ",
        start_at_seconds: 193,
        duration_seconds: 20,
        elements: [...],
        element_count: 4,
        expected_ctr_boost: "15-25%",
        optimization_tips: [...]
      }}
  """

  use Lux.Prism,
    name: "Optimize YouTube End Screens",
    description: "Generates an optimized end screen layout to maximize subscriber and view conversion",
    input_schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "The YouTube video ID to optimize end screens for"
        },
        video_duration_seconds: %{
          type: :integer,
          description: "Total video duration in seconds (minimum 25 seconds for end screens)"
        },
        channel_id: %{
          type: :string,
          description: "The channel ID for context-aware optimization"
        },
        top_performing_videos: %{
          type: :array,
          description: "List of top-performing videos with id and title for card suggestions",
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              title: %{type: :string}
            }
          }
        }
      },
      required: ["video_id", "video_duration_seconds"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        start_at_seconds: %{type: :integer, description: "When the end screen begins"},
        duration_seconds: %{type: :integer, description: "End screen display duration"},
        elements: %{
          type: :array,
          description: "Ordered list of end screen elements by priority"
        },
        element_count: %{type: :integer},
        expected_ctr_boost: %{type: :string, description: "Estimated CTR improvement range"},
        optimization_tips: %{type: :array, description: "Actionable tips to improve end screen performance"}
      },
      required: ["video_id", "start_at_seconds", "elements"]
    }

  require Logger

  @end_screen_duration 20
  @minimum_video_duration 25

  @doc """
  Generates the optimized end screen layout for the given video.
  """
  @impl true
  def handler(params, agent) do
    with {:ok, video_id} <- validate_video_id(params),
         {:ok, duration} <- validate_duration(params) do
      channel_id = params["channel_id"] || params[:channel_id]
      top_videos = params["top_performing_videos"] || params[:top_performing_videos] || []

      agent_name = get_in(agent, [:agent, :name]) || get_in(agent, ["agent", "name"]) || "Unknown"
      Logger.info("Agent #{agent_name} optimizing end screens for video #{video_id} (#{duration}s)")

      start_at = max(duration - @end_screen_duration, 0)
      elements = build_elements(top_videos, channel_id)
      ctr_boost = estimate_ctr_boost(length(elements), top_videos)
      tips = generate_optimization_tips(duration, top_videos)

      {:ok, %{
        video_id: video_id,
        start_at_seconds: start_at,
        duration_seconds: @end_screen_duration,
        elements: elements,
        element_count: length(elements),
        expected_ctr_boost: ctr_boost,
        optimization_tips: tips
      }}
    end
  end

  defp validate_video_id(params) do
    case params["video_id"] || params[:video_id] do
      nil -> {:error, "Missing required parameter: video_id"}
      "" -> {:error, "video_id cannot be empty"}
      id -> {:ok, id}
    end
  end

  defp validate_duration(params) do
    duration = params["video_duration_seconds"] || params[:video_duration_seconds]

    cond do
      is_nil(duration) ->
        {:error, "Missing required parameter: video_duration_seconds"}

      not is_integer(duration) ->
        {:error, "video_duration_seconds must be an integer"}

      duration < @minimum_video_duration ->
        {:error, "Video must be at least #{@minimum_video_duration} seconds for end screens"}

      true ->
        {:ok, duration}
    end
  end

  defp build_elements(top_videos, channel_id) do
    base_elements = [
      %{
        type: "subscribe",
        label: "Subscribe",
        position: %{left: "5%", top: "35%"},
        priority: 1,
        description: "Subscribe button — highest-priority element for channel growth"
      },
      %{
        type: "video",
        subtype: "latest",
        label: "Latest Upload",
        position: %{left: "55%", top: "15%"},
        priority: 2,
        description: "Your most recent upload to keep viewers on your channel"
      }
    ]

    video_elements =
      case top_videos do
        [best | _] ->
          [
            %{
              type: "video",
              subtype: "best_for_viewer",
              label: best["title"] || best[:title] || "Best For Viewer",
              video_id: best["id"] || best[:id],
              position: %{left: "55%", top: "55%"},
              priority: 3,
              description: "YouTube's algorithm picks the best video for each viewer"
            }
          ]

        [] ->
          [
            %{
              type: "video",
              subtype: "best_for_viewer",
              label: "Best For Viewer",
              position: %{left: "55%", top: "55%"},
              priority: 3,
              description: "YouTube's algorithm picks the best video for each viewer"
            }
          ]
      end

    playlist_element =
      if channel_id do
        [
          %{
            type: "playlist",
            label: "Featured Playlist",
            channel_id: channel_id,
            position: %{left: "5%", top: "65%"},
            priority: 4,
            description: "Featured playlist to encourage binge-watching"
          }
        ]
      else
        []
      end

    base_elements ++ video_elements ++ playlist_element
  end

  defp estimate_ctr_boost(element_count, top_videos) do
    has_top_video = length(top_videos) > 0

    cond do
      element_count >= 4 and has_top_video -> "20-30%"
      element_count >= 4 -> "15-25%"
      element_count >= 3 -> "10-20%"
      element_count >= 2 -> "5-15%"
      true -> "2-8%"
    end
  end

  defp generate_optimization_tips(duration, top_videos) do
    base_tips = [
      "Add a verbal CTA at #{max(duration - 25, 0)}s prompting viewers to click the subscribe button",
      "Use the 'Best For Viewer' card — YouTube's algorithm improves CTR by 20-40% vs. manual picks",
      "Keep end screen visually uncluttered — limit to 3-4 elements maximum"
    ]

    video_tips =
      if length(top_videos) > 0 do
        ["Place your highest-CTR video in the top-right position for maximum visibility"]
      else
        ["Provide top_performing_videos data to enable personalized card selection"]
      end

    duration_tips =
      if duration > 300 do
        ["Consider adding a chapter marker at #{duration - 30}s to signal the end screen is coming"]
      else
        []
      end

    base_tips ++ video_tips ++ duration_tips
  end
end
