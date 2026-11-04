defmodule Lux.YouTube.ContentIntelligence.AudienceEngagement do
  @moduledoc """
  Audience engagement analysis for YouTube content intelligence.

  Provides loyalty scoring, subscriber vs non-subscriber watch ratios,
  traffic source classification, and engagement grading.
  """

  @doc """
  Analyzes audience engagement metrics.

  ## Parameters

    * `subscribers` - Subscriber count
    * `non_subscriber_watch_time` - Watch time from non-subscribers (minutes)
    * `subscriber_watch_time` - Watch time from subscribers (minutes)
    * `traffic_sources` - Map of traffic source to view count
    * `likes` - Like count
    * `dislikes` - Dislike count
    * `comments` - Comment count
    * `views` - Total view count

  ## Returns

    * `{:ok, result}` - Engagement analysis results
    * `{:error, reason}` - If input is invalid
  """
  def analyze(input) when is_map(input) do
    with {:ok, validated} <- validate_input(input) do
      loyalty_score = calculate_loyalty_score(validated)
      subscriber_ratio = calculate_subscriber_ratio(validated)
      traffic_classification = classify_traffic_sources(validated.traffic_sources)
      engagement_grade = calculate_engagement_grade(validated)

      {:ok, %{
        loyalty_score: loyalty_score,
        subscriber_vs_non_subscriber_ratio: subscriber_ratio,
        traffic_source_classification: traffic_classification,
        engagement_grade: engagement_grade,
        engagement_rate: calculate_engagement_rate(validated),
        subscriber_retention_rate: calculate_subscriber_retention(validated)
      }}
    end
  end

  def analyze(_input), do: {:error, :invalid_input}

  @doc """
  Calculates audience loyalty score (0-100).
  """
  def loyalty_score(subscriber_watch_time, total_watch_time) when is_integer(subscriber_watch_time) and is_integer(total_watch_time) do
    if total_watch_time > 0 do
      round((subscriber_watch_time / total_watch_time) * 100)
    else
      0
    end
  end

  def loyalty_score(_, _), do: {:error, :invalid_input}

  @doc """
  Calculates subscriber vs non-subscriber watch ratio.
  """
  def subscriber_ratio(subscriber_watch_time, non_subscriber_watch_time) when is_integer(subscriber_watch_time) and is_integer(non_subscriber_watch_time) do
    total = subscriber_watch_time + non_subscriber_watch_time
    if total > 0 do
      %{subscriber: round((subscriber_watch_time / total) * 100),
        non_subscriber: round((non_subscriber_watch_time / total) * 100)}
    else
      %{subscriber: 0, non_subscriber: 0}
    end
  end

  def subscriber_ratio(_, _), do: {:error, :invalid_input}

  @doc """
  Classifies traffic sources by dominance.
  """
  def classify_traffic_sources(traffic_sources) when is_map(traffic_sources) do
    total = Map.values(traffic_sources) |> Enum.sum()
    if total > 0 do
      traffic_sources
      |> Enum.sort_by(fn {_, count} -> -count end)
      |> Enum.map(fn {source, count} ->
        %{source: source, percentage: round((count / total) * 100), views: count}
      end)
    else
      []
    end
  end

  def classify_traffic_sources(_), do: {:error, :invalid_input}

  @doc """
  Calculates engagement grade (A-F) based on engagement metrics.
  """
  def engagement_grade(engagement_rate) when is_number(engagement_rate) do
    cond do
      engagement_rate >= 10 -> "A"
      engagement_rate >= 7 -> "B"
      engagement_rate >= 5 -> "C"
      engagement_rate >= 3 -> "D"
      true -> "F"
    end
  end

  def engagement_grade(_), do: {:error, :invalid_input}

  # Private helpers

  defp validate_input(input) do
    required = [:subscribers, :non_subscriber_watch_time, :subscriber_watch_time,
                :traffic_sources, :likes, :dislikes, :comments, :views]

    missing = Enum.filter(required, fn key -> not Map.has_key?(input, key) end)

    if missing != [] do
      {:error, {:missing_fields, missing}}
    else
      cond do
        input.views < 0 -> {:error, {:invalid_value, :views}}
        input.subscribers < 0 -> {:error, {:invalid_value, :subscribers}}
        true -> {:ok, input}
      end
    end
  end

  defp calculate_loyalty_score(input) do
    total = input.subscriber_watch_time + input.non_subscriber_watch_time
    loyalty_score(input.subscriber_watch_time, total)
  end

  defp calculate_subscriber_ratio(input) do
    subscriber_ratio(input.subscriber_watch_time, input.non_subscriber_watch_time)
  end

  defp calculate_engagement_grade(input) do
    rate = calculate_engagement_rate(input)
    engagement_grade(rate)
  end

  defp calculate_engagement_rate(input) do
    total_engagement = Map.get(input, :likes, 0) + Map.get(input, :comments, 0)
    if input.views > 0 do
      round((total_engagement / input.views) * 100 * 100) / 100
    else
      0.0
    end
  end

  defp calculate_subscriber_retention(input) do
    if input.subscribers > 0 and input.views > 0 do
      round((input.subscribers / input.views) * 100 * 100) / 100
    else
      0.0
    end
  end
end