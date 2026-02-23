defmodule Lux.Prisms.YouTube.GenerateContentRecommendations do
  @moduledoc """
  A prism for generating a data-driven content calendar for YouTube channels.

  Fetches trending topics via SearchTrendingTopics lens (or uses provided topics),
  then generates a content calendar of recommended video ideas with titles, topics,
  estimated views, and strategic reasoning.

  ## Examples

      iex> GenerateContentRecommendations.handler(%{
      ...>   "channel_id" => "UCxxxxxx",
      ...>   "topic_focus" => "elixir programming"
      ...> }, %{})
      {:ok, %{
        content_calendar: [
          %{
            title: "Elixir GenServer Tutorial for Beginners",
            topic: "elixir programming",
            estimated_views: 25_000,
            priority: "high",
            reasoning: "Trending keyword with low competition",
            suggested_format: "tutorial",
            suggested_length: "10-20 min"
          }
        ],
        strategy_summary: "Focus on educational content in the elixir programming niche",
        topics_analyzed: 5
      }}
  """

  use Lux.Prism,
    name: "Generate Content Recommendations",
    description: "Generates a data-driven YouTube content calendar using trending topic analysis",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "YouTube channel ID for context (optional)"
        },
        topic_focus: %{
          type: :string,
          description: "Primary topic/niche to generate recommendations for"
        },
        trending_topics: %{
          type: :array,
          items: %{type: :object},
          description: "Pre-fetched trending topics to use instead of calling the lens"
        },
        num_recommendations: %{
          type: :integer,
          description: "Number of video ideas to generate",
          default: 5,
          minimum: 1,
          maximum: 20
        }
      },
      required: ["topic_focus"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content_calendar: %{type: :array, items: %{type: :object}},
        strategy_summary: %{type: :string},
        topics_analyzed: %{type: :integer}
      }
    }

  alias Lux.Lenses.YouTube.Analytics.SearchTrendingTopics

  @doc """
  Generates content recommendations based on trending topics in the given niche.
  """
  def handler(params, _agent) do
    topic_focus = params["topic_focus"] || params[:topic_focus] || ""
    num_recs = params["num_recommendations"] || params[:num_recommendations] || 5
    provided_topics = params["trending_topics"] || params[:trending_topics]

    with {:ok, topics} <- fetch_topics(provided_topics, topic_focus) do
      calendar = generate_calendar(topics, topic_focus, num_recs)
      summary = build_strategy_summary(topic_focus, calendar)

      {:ok, %{
        content_calendar: calendar,
        strategy_summary: summary,
        topics_analyzed: length(topics),
        topic_focus: topic_focus
      }}
    end
  end

  defp fetch_topics(nil, topic_focus) do
    case SearchTrendingTopics.focus(%{"query" => topic_focus, "max_results" => 10}, %{}) do
      {:ok, result} -> {:ok, result.topics}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_topics(provided_topics, _topic_focus) when is_list(provided_topics) do
    {:ok, provided_topics}
  end

  defp generate_calendar(topics, topic_focus, num_recs) do
    trending_ideas = topics |> Enum.take(num_recs) |> Enum.map(&topic_to_idea(&1, topic_focus))
    gap_ideas = gap_ideas(topic_focus, max(num_recs - length(trending_ideas), 0))

    (trending_ideas ++ gap_ideas)
    |> Enum.take(num_recs)
    |> Enum.with_index(1)
    |> Enum.map(fn {idea, rank} -> Map.put(idea, :calendar_week, rank) end)
  end

  defp topic_to_idea(topic, topic_focus) do
    title = generate_title(topic[:title] || "#{topic_focus} explained", topic_focus)
    format = suggest_format(topic[:title] || "")
    length = suggest_length(format)
    estimated_views = estimate_views(topic[:trending_score] || 50)

    %{
      title: title,
      topic: topic_focus,
      source_video_title: topic[:title],
      estimated_views: estimated_views,
      priority: priority_from_score(topic[:trending_score] || 50),
      reasoning: build_reasoning(topic, topic_focus),
      suggested_format: format,
      suggested_length: length,
      tags: extract_tags(topic[:title] || topic_focus)
    }
  end

  defp gap_ideas(_topic_focus, 0), do: []

  defp gap_ideas(topic_focus, count) do
    formats = ["beginner tutorial", "deep dive", "common mistakes", "vs comparison", "project walkthrough"]

    formats
    |> Enum.take(count)
    |> Enum.map(fn format ->
      title = "#{String.capitalize(topic_focus)}: #{String.capitalize(format)}"
      %{
        title: title,
        topic: topic_focus,
        source_video_title: nil,
        estimated_views: 15_000,
        priority: "medium",
        reasoning: "Content gap opportunity — #{format} format underrepresented in niche",
        suggested_format: String.split(format) |> List.first(),
        suggested_length: suggest_length(format),
        tags: extract_tags(title)
      }
    end)
  end

  defp generate_title(source_title, topic_focus) do
    cond do
      String.contains?(String.downcase(source_title), String.downcase(topic_focus)) ->
        source_title

      String.length(source_title) > 60 ->
        "#{topic_focus}: #{source_title |> String.split() |> Enum.take(5) |> Enum.join(" ")}..."

      true ->
        "#{topic_focus} — #{source_title}"
    end
  end

  defp suggest_format(title) do
    title_lower = String.downcase(title)
    cond do
      String.contains?(title_lower, ["tutorial", "how to", "guide", "learn"]) -> "tutorial"
      String.contains?(title_lower, ["review", "vs", "compare"])               -> "review"
      String.contains?(title_lower, ["top", "best", "ranked"])                 -> "listicle"
      String.contains?(title_lower, ["build", "create", "make", "project"])    -> "project"
      true                                                                      -> "explainer"
    end
  end

  defp suggest_length(format) do
    case format do
      "tutorial"  -> "10-20 min"
      "project"   -> "20-40 min"
      "review"    -> "8-15 min"
      "listicle"  -> "5-12 min"
      _           -> "8-15 min"
    end
  end

  defp estimate_views(trending_score) when trending_score >= 80, do: 100_000
  defp estimate_views(trending_score) when trending_score >= 60, do: 50_000
  defp estimate_views(trending_score) when trending_score >= 40, do: 25_000
  defp estimate_views(_), do: 10_000

  defp priority_from_score(score) when score >= 80, do: "high"
  defp priority_from_score(score) when score >= 50, do: "medium"
  defp priority_from_score(_), do: "low"

  defp build_reasoning(topic, topic_focus) do
    score = topic[:trending_score] || 50
    "Trending in #{topic_focus} niche (score: #{score}/100). " <>
      "Capitalize on audience demand with a fresh perspective on this topic."
  end

  defp extract_tags(title) do
    title
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.uniq()
    |> Enum.take(5)
  end

  defp build_strategy_summary(topic_focus, calendar) do
    high_count = Enum.count(calendar, &(&1.priority == "high"))
    formats = calendar |> Enum.map(& &1.suggested_format) |> Enum.uniq() |> Enum.join(", ")

    "Focus on #{topic_focus} content with #{length(calendar)} planned videos " <>
      "(#{high_count} high-priority). Recommended formats: #{formats}. " <>
      "Publish consistently — 1-2 videos per week for optimal algorithmic growth."
  end
end
