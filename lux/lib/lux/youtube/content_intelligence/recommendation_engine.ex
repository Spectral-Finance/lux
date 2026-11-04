defmodule Lux.YouTube.ContentIntelligence.RecommendationEngine do
  @moduledoc """
  Content recommendation engine for YouTube content intelligence.

  Generates next video topic recommendations from top historical performers
  and discovers search gaps.
  """

  @doc """
  Generates content recommendations based on historical performance.

  ## Parameters

    * `historical_videos` - List of video performance maps
    * `channel_niche` - Channel niche/topic category
    * `max_recommendations` - Maximum number of recommendations (default: 5)

  ## Returns

    * `{:ok, result}` - Recommendation results
    * `{:error, reason}` - If input is invalid
  """
  def recommend(input) when is_map(input) do
    with {:ok, validated} <- validate_input(input) do
      top_performers = select_top_performers(validated.historical_videos)
      search_gaps = discover_search_gaps(validated.historical_videos)
      recommendations = generate_recommendations(top_performers, validated.channel_niche)

      {:ok, %{
        recommended_topics: recommendations,
        search_gaps: search_gaps,
        top_performing_topics: Enum.map(top_performers, &Map.get(&1, :topic, "unknown")),
        next_video_suggestions: take(recommendations, validated.max_recommendations)
      }}
    end
  end

  def recommend(_input), do: {:error, :invalid_input}

  @doc """
  Selects top performing videos from historical data.
  """
  def select_top_performers(videos) when is_list(videos) do
    videos
    |> Enum.sort_by(fn v -> -(Map.get(v, :views, 0) + Map.get(v, :likes, 0)) end)
    |> Enum.take(10)
  end

  def select_top_performers(_), do: {:error, :invalid_input}

  @doc """
  Discovers search gaps - topics with high demand but low competition.
  """
  def discover_search_gaps(videos) when is_list(videos) do
    covered_topics = videos |> Enum.map(&Map.get(&1, :topic, "unknown")) |> Enum.uniq()

    common_gaps = ["how-to", "tutorial", "review", "comparison", "beginner guide"]
    Enum.filter(common_gaps, fn topic -> topic not in covered_topics end)
  end

  def discover_search_gaps(_), do: {:error, :invalid_input}

  @doc """
  Generates topic recommendations from top performers.
  """
  def generate_recommendations(top_performers, channel_niche) when is_list(top_performers) and is_binary(channel_niche) do
    Enum.map(top_performers, fn video ->
      topic = Map.get(video, :topic, "unknown")
      views = Map.get(video, :views, 0)
      %{topic: "#{topic} - advanced guide", niche: channel_niche,
        potential_views: round(views * 0.8), confidence: 0.75}
    end)
  end

  def generate_recommendations(_, _), do: {:error, :invalid_input}

  # Private helpers

  defp validate_input(input) do
    required = [:historical_videos, :channel_niche]

    missing = Enum.filter(required, fn key -> not Map.has_key?(input, key) end)

    if missing != [] do
      {:error, {:missing_fields, missing}}
    else
      cond do
        not is_list(input.historical_videos) -> {:error, {:invalid_value, :historical_videos}}
        not is_binary(input.channel_niche) -> {:error, {:invalid_value, :channel_niche}}
        true -> {:ok, Map.put(input, :max_recommendations, Map.get(input, :max_recommendations, 5))}
      end
    end
  end

  defp take(list, n), do: Enum.take(list, n)
end