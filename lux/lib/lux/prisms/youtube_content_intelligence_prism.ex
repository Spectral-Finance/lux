defmodule Lux.Prisms.YouTubeContentIntelligencePrism do
  @moduledoc """
  First-class agent Prism for the YouTube Content Intelligence System.

  Wraps the unified Lux.YouTube.ContentIntelligence facade as a Prism
  that agents can use for content analysis, optimization, and
  automated decision-making for YouTube channels.

  ## Examples

      iex> Lux.Prisms.YouTubeContentIntelligencePrism.run(%{
      iex>   action: "analyze_video",
      iex>   video_data: %{
      iex>     views: 10000,
      iex>     watch_time_minutes: 5000,
      iex>     video_length_seconds: 600,
      iex>     published_at: ~U[2024-01-01 12:00:00Z],
      iex>     current_time: ~U[2024-01-02 12:00:00Z]
      iex>   }
      iex> })
      {:ok, %{performance: %{view_velocity_per_hour: 416.67, ...}, ...}}

  """

  use Lux.Prism,
    name: "YouTube Content Intelligence",
    description: "Intelligent system for content analysis, optimization, and automated decision-making for YouTube channels",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["analyze_video", "performance", "engagement", "recommendations",
                 "posting_times", "title_thumbnail", "metadata", "trending_topics",
                 "modules"],
          description: "The intelligence action to perform"
        },
        video_data: %{
          type: :object,
          description: "Video metadata and performance data"
        },
        options: %{
          type: :object,
          description: "Optional configuration"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: :object, description: "The intelligence result"},
        action: %{type: :string, description: "The action that was performed"}
      },
      required: ["result", "action"]
    }

  def handler(%{"action" => action, "video_data" => video_data}, _ctx) do
    result = dispatch_action(action, video_data)

    case result do
      {:ok, data} -> {:ok, %{"result" => data, "action" => action}}
      {:error, reason} -> {:error, reason}
    end
  end

  def handler(%{"action" => "modules"} = _input, _ctx) do
    {:ok, %{"result" => Lux.YouTube.ContentIntelligence.modules(), "action" => "modules"}}
  end

  def handler(%{"action" => _action}, _ctx) do
    {:error, {:missing_field, "video_data"}}
  end

  def handler(_input, _ctx) do
    {:error, {:missing_field, "action"}}
  end

  defp dispatch_action("analyze_video", video_data), do: Lux.YouTube.ContentIntelligence.analyze_video(video_data)
  defp dispatch_action("performance", video_data), do: Lux.YouTube.ContentIntelligence.performance(video_data)
  defp dispatch_action("engagement", video_data), do: Lux.YouTube.ContentIntelligence.engagement(video_data)
  defp dispatch_action("recommendations", video_data), do: Lux.YouTube.ContentIntelligence.recommendations(video_data)
  defp dispatch_action("posting_times", video_data), do: Lux.YouTube.ContentIntelligence.posting_times(video_data)
  defp dispatch_action("title_thumbnail", video_data), do: Lux.YouTube.ContentIntelligence.title_thumbnail(video_data)
  defp dispatch_action("metadata", video_data), do: Lux.YouTube.ContentIntelligence.metadata(video_data)
  defp dispatch_action("trending_topics", video_data), do: Lux.YouTube.ContentIntelligence.trending_topics(video_data)
  defp dispatch_action("modules", _video_data), do: {:ok, Lux.YouTube.ContentIntelligence.modules()}
  defp dispatch_action(action, _video_data), do: {:error, {:unknown_action, action}}
end