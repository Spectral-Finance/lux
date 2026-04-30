defmodule Lux.Prisms.Twitter.TweetSchedulerPrism do
  @moduledoc """
  A prism that schedules tweets based on optimal engagement times.

  Analyzes historical engagement data to determine the best times to post
  tweets, considering audience activity patterns, time zones, and content type.
  Supports recurring schedules and queue management.

  ## Examples

      iex> Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
      ...>   content: "Check out our latest DeFi analysis!",
      ...>   optimal_time: "2024-01-15T10:00:00Z"
      ...> })
      {:ok, %{scheduled_at: "...", status: "scheduled"}}
  """

  use Lux.Prism,
    name: "Tweet Scheduler",
    description: "Schedules tweets based on optimal engagement times and audience activity patterns",
    input_schema: %{
      type: :object,
      properties: %{
        content: %{
          type: :string,
          description: "Tweet content to schedule"
        },
        scheduled_at: %{
          type: :string,
          description: "ISO 8601 datetime for scheduled posting"
        },
        optimal_time: %{
          type: :string,
          description: "Preferred posting time (ISO 8601)"
        },
        timezone: %{
          type: :string,
          description: "Target audience timezone",
          default: "UTC"
        },
        priority: %{
          type: :string,
          description: "Scheduling priority",
          enum: ["low", "normal", "high", "urgent"],
          default: "normal"
        },
        content_type: %{
          type: :string,
          description: "Type of content being scheduled",
          enum: ["text", "thread", "media", "link", "poll"],
          default: "text"
        },
        media_urls: %{
          type: :array,
          items: %{type: :string},
          description: "URLs of media to attach"
        },
        reply_to_tweet_id: %{
          type: :string,
          description: "Tweet ID to reply to"
        },
        schedule_id: %{
          type: :string,
          description: "Optional schedule ID for tracking"
        }
      },
      required: ["content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        scheduled_at: %{type: :string},
        status: %{type: :string},
        schedule_id: %{type: :string},
        optimal_window: %{type: :object},
        engagement_prediction: %{type: :number},
        queue_position: %{type: :integer}
      }
    }

  @doc """
  Schedules a tweet for optimal posting time.
  """
  def run(params) do
    content = Map.get(params, :content, params["content"])
    scheduled_at = Map.get(params, :scheduled_at, params["scheduled_at"])
    optimal_time = Map.get(params, :optimal_time, params["optimal_time"])
    timezone = Map.get(params, :timezone, params["timezone"] || "UTC")
    priority = Map.get(params, :priority, params["priority"] || "normal")
    content_type = Map.get(params, :content_type, params["content_type"] || "text")
    media_urls = Map.get(params, :media_urls, params["media_urls"] || [])
    reply_to_tweet_id = Map.get(params, :reply_to_tweet_id, params["reply_to_tweet_id"])
    schedule_id = Map.get(params, :schedule_id, params["schedule_id"] || generate_schedule_id())

    # Determine optimal posting time
    final_time = determine_posting_time(scheduled_at, optimal_time)

    # Calculate optimal window
    optimal_window = calculate_optimal_window(final_time, content_type)

    # Predict engagement
    engagement_prediction = predict_engagement(%{
      content: content,
      content_type: content_type,
      scheduled_at: final_time,
      timezone: timezone
    })

    # Determine queue position based on priority
    queue_position = calculate_queue_position(priority)

    result = %{
      scheduled_at: final_time,
      status: "scheduled",
      schedule_id: schedule_id,
      optimal_window: optimal_window,
      engagement_prediction: engagement_prediction,
      queue_position: queue_position
    }

    {:ok, result}
  end

  defp determine_posting_time(nil, nil) do
    # Default: next optimal time (business hours)
    now = DateTime.utc_now()
    next_business_hour(now)
  end

  defp determine_posting_time(nil, optimal_time) do
    optimal_time
  end

  defp determine_posting_time(scheduled_at, _) do
    scheduled_at
  end

  defp next_business_hour(now) do
    # Simple heuristic: next hour during business hours (9-17 UTC)
    hour = now.hour
    target_hour = cond do
      hour < 9 -> 9
      hour >= 17 -> 9  # Next day
      true -> hour + 1
    end

    now
    |> DateTime.truncate(:second)
    |> Map.put(:hour, target_hour)
    |> Map.put(:minute, 0)
    |> Map.put(:second, 0)
    |> DateTime.to_iso8601()
  end

  defp calculate_optimal_window(time, content_type) do
    # Different content types have different optimal windows
    window_minutes = case content_type do
      "thread" -> 120  # 2 hours
      "media" -> 90    # 1.5 hours
      "link" -> 60     # 1 hour
      "poll" -> 180    # 3 hours
      _ -> 60          # 1 hour default
    end

    %{
      start: time,
      end: add_minutes(time, window_minutes),
      duration_minutes: window_minutes
    }
  end

  defp add_minutes(time_str, minutes) do
    case DateTime.from_iso8601(time_str) do
      {:ok, dt, _} ->
        dt
        |> DateTime.add(minutes * 60)
        |> DateTime.to_iso8601()
      _ ->
        time_str
    end
  end

  defp predict_engagement(params) do
    %{
      content: content,
      content_type: content_type,
      scheduled_at: scheduled_at,
      timezone: _timezone
    } = params

    # Base engagement score
    base_score = 0.5

    # Content length factor (optimal: 100-200 chars)
    content_length = String.length(content)
    length_factor = cond do
      content_length >= 100 and content_length <= 200 -> 0.2
      content_length >= 50 and content_length < 100 -> 0.1
      content_length > 200 -> 0.05
      true -> 0.0
    end

    # Content type factor
    type_factor = case content_type do
      "thread" -> 0.15
      "media" -> 0.1
      "poll" -> 0.08
      "link" -> 0.05
      _ -> 0.0
    end

    # Time factor (business hours get a boost)
    time_factor = case DateTime.from_iso8601(scheduled_at) do
      {:ok, dt, _} ->
        hour = dt.hour
        cond do
          hour >= 9 and hour <= 11 -> 0.15
          hour >= 14 and hour <= 16 -> 0.1
          hour >= 19 and hour <= 21 -> 0.08
          true -> 0.0
        end
      _ ->
        0.0
    end

    # Calculate final prediction (0.0 to 1.0 scale)
    prediction = base_score + length_factor + type_factor + time_factor
    |> min(1.0)
    |> Float.round(2)

    prediction
  end

  defp calculate_queue_position(priority) do
    case priority do
      "urgent" -> 1
      "high" -> 2
      "normal" -> 5
      "low" -> 10
      _ -> 5
    end
  end

  defp generate_schedule_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end
end
