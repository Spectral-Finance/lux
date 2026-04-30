defmodule Lux.Prisms.Twitter.ContentCalendarPrism do
  @moduledoc """
  A prism that generates and manages a content calendar for Twitter.

  Creates a structured posting schedule with diverse content types,
  maintains content balance across categories, and optimizes posting
  frequency for maximum engagement. Supports weekly and monthly calendars.

  ## Examples

      iex> Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
      ...>   week_start: "2024-01-15",
      ...>   content_categories: ["analysis", "news", "engagement"]
      ...> })
      {:ok, %{calendar: [...], summary: %{...}}}
  """

  use Lux.Prism,
    name: "Content Calendar",
    description: "Generates and manages a structured Twitter content calendar with optimal posting schedules",
    input_schema: %{
      type: :object,
      properties: %{
        week_start: %{
          type: :string,
          description: "Start date of the calendar week (YYYY-MM-DD)"
        },
        duration_weeks: %{
          type: :integer,
          description: "Number of weeks to generate calendar for",
          default: 1
        },
        posts_per_day: %{
          type: :integer,
          description: "Target number of posts per day",
          default: 2
        },
        content_categories: %{
          type: :array,
          items: %{type: :string},
          description: "Content categories to include in the calendar",
          default: ["analysis", "news", "engagement", "educational", "community"]
        },
        timezone: %{
          type: :string,
          description: "Target timezone for scheduling",
          default: "UTC"
        },
        exclude_dates: %{
          type: :array,
          items: %{type: :string},
          description: "Dates to exclude from scheduling (YYYY-MM-DD)"
        },
        tone: %{
          type: :string,
          description: "Overall tone for content",
          enum: ["professional", "casual", "educational", "engaging"],
          default: "professional"
        }
      },
      required: ["week_start"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        calendar: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              date: %{type: :string},
              time: %{type: :string},
              category: %{type: :string},
              content_type: %{type: :string},
              topic: %{type: :string},
              suggested_content: %{type: :string},
              priority: %{type: :string}
            }
          }
        },
        summary: %{
          type: :object,
          properties: %{
            total_posts: %{type: :integer},
            category_distribution: %{type: :object},
            daily_average: %{type: :number},
            optimal_posting_times: %{type: :array}
          }
        },
        recommendations: %{type: :array}
      }
    }

  @doc """
  Generates a content calendar based on the provided parameters.
  """
  def run(params) do
    week_start = Map.get(params, :week_start, params["week_start"])
    duration_weeks = Map.get(params, :duration_weeks, params["duration_weeks"] || 1)
    posts_per_day = Map.get(params, :posts_per_day, params["posts_per_day"] || 2)
    content_categories = Map.get(params, :content_categories, params["content_categories"] || ["analysis", "news", "engagement", "educational", "community"])
    timezone = Map.get(params, :timezone, params["timezone"] || "UTC")
    exclude_dates = Map.get(params, :exclude_dates, params["exclude_dates"] || [])
    tone = Map.get(params, :tone, params["tone"] || "professional")

    # Generate calendar entries
    calendar = generate_calendar(%{
      week_start: week_start,
      duration_weeks: duration_weeks,
      posts_per_day: posts_per_day,
      content_categories: content_categories,
      exclude_dates: exclude_dates,
      tone: tone
    })

    # Calculate summary
    summary = calculate_summary(calendar, posts_per_day)

    # Generate recommendations
    recommendations = generate_recommendations(calendar, content_categories)

    result = %{
      calendar: calendar,
      summary: summary,
      recommendations: recommendations
    }

    {:ok, result}
  end

  defp generate_calendar(params) do
    %{
      week_start: week_start,
      duration_weeks: duration_weeks,
      posts_per_day: posts_per_day,
      content_categories: categories,
      exclude_dates: exclude_dates,
      tone: tone
    } = params

    start_date = Date.from_iso8601!(week_start)
    total_days = duration_weeks * 7

    # Generate dates
    dates = 0..(total_days - 1)
    |> Enum.map(&Date.add(start_date, &1))
    |> Enum.reject(fn date ->
      date_str = Date.to_iso8601(date)
      date_str in exclude_dates
    end)

    # Generate posts for each date
    Enum.flat_map(dates, fn date ->
      date_str = Date.to_iso8601(date)
      day_of_week = Date.day_of_week(date)

      # Adjust posts based on day of week
      adjusted_posts = case day_of_week do
        6 -> max(1, posts_per_day - 1)  # Saturday: slightly less
        7 -> max(1, posts_per_day - 1)  # Sunday: slightly less
        _ -> posts_per_day
      end

      # Generate posting times based on day
      posting_times = get_posting_times(day_of_week, adjusted_posts)

      # Generate content for each slot
      Enum.with_index(posting_times)
      |> Enum.map(fn {time, index} ->
        category = Enum.at(categories, rem(index, length(categories)))
        content_type = get_content_type(category, day_of_week)
        topic = generate_topic(category, tone)

        %{
          date: date_str,
          time: time,
          category: category,
          content_type: content_type,
          topic: topic,
          suggested_content: generate_suggested_content(category, topic, tone),
          priority: get_priority(category, day_of_week)
        }
      end)
    end)
  end

  defp get_posting_times(day_of_week, count) do
    # Optimal posting times based on day
    base_times = case day_of_week do
      1 -> ["09:00", "14:00", "19:00"]  # Monday
      2 -> ["08:00", "13:00", "18:00"]  # Tuesday
      3 -> ["09:00", "12:00", "17:00"]  # Wednesday
      4 -> ["10:00", "15:00", "20:00"]  # Thursday
      5 -> ["09:00", "14:00", "19:00"]  # Friday
      6 -> ["10:00", "16:00"]           # Saturday
      7 -> ["11:00", "17:00"]           # Sunday
      _ -> ["09:00", "14:00"]
    end

    Enum.take(base_times, count)
  end

  defp get_content_type(category, _day_of_week) do
    case category do
      "analysis" -> "thread"
      "news" -> "text"
      "engagement" -> "poll"
      "educational" -> "thread"
      "community" -> "text"
      _ -> "text"
    end
  end

  defp generate_topic(category, tone) do
    topics = %{
      "analysis" => [
        "Market Analysis: Key Trends to Watch",
        "DeFi Protocol Performance Breakdown",
        "Token Economics Deep Dive",
        "On-Chain Metrics Analysis"
      ],
      "news" => [
        "Protocol Update: What You Need to Know",
        "Industry News Roundup",
        "Partnership Announcement",
        "Product Launch Update"
      ],
      "engagement" => [
        "What's Your Favorite DeFi Protocol?",
        "Bullish or Bearish This Week?",
        "Poll: Which Chain Has the Best UX?",
        "Community Discussion: Top Picks"
      ],
      "educational" => [
        "Understanding Yield Farming",
        "How to Read On-Chain Data",
        "Smart Contract Security Basics",
        "DeFi Risk Management Guide"
      ],
      "community" => [
        "Community Spotlight: Member of the Week",
        "AMA Announcement",
        "Behind the Scenes",
        "Team Introduction"
      ]
    }

    category_topics = Map.get(topics, category, topics["news"])
    Enum.random(category_topics)
  end

  defp generate_suggested_content(category, topic, tone) do
    prefix = case tone do
      "professional" -> "📊"
      "casual" -> "✨"
      "educational" -> "📚"
      "engaging" -> "🔥"
      _ -> "📌"
    end

    case category do
      "analysis" ->
        "#{prefix} #{topic}\n\nKey findings from our latest analysis:\n• Trend 1: [Data point]\n• Trend 2: [Data point]\n• Trend 3: [Data point]\n\nFull thread below 👇"
      "news" ->
        "#{prefix} #{topic}\n\nBreaking: [Key update]\n\nWhat this means:\n→ Impact 1\n→ Impact 2\n\nThread 🧵"
      "engagement" ->
        "#{prefix} #{topic}\n\nDrop your thoughts below! 👇"
      "educational" ->
        "#{prefix} #{topic}\n\n1/ [First point]\n2/ [Second point]\n3/ [Third point]\n\nSave this for later! 📌"
      "community" ->
        "#{prefix} #{topic}\n\n[Community highlight]\n\nJoin the conversation! 💬"
      _ ->
        "#{prefix} #{topic}"
    end
  end

  defp get_priority(category, day_of_week) do
    case {category, day_of_week} do
      {"news", d} when d in [1, 2, 3] -> "high"
      {"analysis", d} when d in [2, 3, 4] -> "high"
      {"engagement", _} -> "medium"
      {"educational", _} -> "medium"
      {"community", _} -> "low"
      _ -> "normal"
    end
  end

  defp calculate_summary(calendar, posts_per_day) do
    total_posts = length(calendar)
    days_with_posts = calendar |> Enum.map(& &1.date) |> Enum.uniq() |> length()

    category_distribution = calendar
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {cat, posts} -> {cat, length(posts)} end)
    |> Enum.into(%{})

    daily_average = if days_with_posts > 0, do: Float.round(total_posts / days_with_posts, 1), else: 0.0

    # Find optimal posting times
    optimal_times = calendar
    |> Enum.group_by(& &1.time)
    |> Enum.sort_by(fn {_time, posts} -> length(posts) end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {time, _} -> time end)

    %{
      total_posts: total_posts,
      category_distribution: category_distribution,
      daily_average: daily_average,
      optimal_posting_times: optimal_times
    }
  end

  defp generate_recommendations(calendar, categories) do
    recommendations = []

    # Check category balance
    category_counts = calendar |> Enum.group_by(& &1.category) |> Enum.map(fn {k, v} -> {k, length(v)} end) |> Enum.into(%{})
    max_count = Enum.max_by(category_counts, fn {_k, v} -> v end, fn -> {nil, 0} end) |> elem(1)
    min_count = Enum.min_by(category_counts, fn {_k, v} -> v end, fn -> {nil, 0} end) |> elem(1)

    recommendations = if max_count > min_count * 2 do
      ["Consider balancing content across categories for consistent audience engagement." | recommendations]
    else
      recommendations
    end

    # Check posting frequency
    total = length(calendar)
    recommendations = if total < 7 do
      ["Consider increasing posting frequency to at least 2 posts per day for better engagement." | recommendations]
    else
      recommendations
    end

    # General recommendations
    recommendations = [
      "Mix content types to keep your audience engaged.",
      "Schedule posts during peak engagement hours (9-11 AM and 2-4 PM).",
      "Include visual content (images, charts) to increase engagement by up to 150%."
    ] ++ recommendations

    recommendations
  end
end
