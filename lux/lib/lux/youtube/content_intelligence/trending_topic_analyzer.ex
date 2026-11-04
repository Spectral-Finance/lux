defmodule Lux.YouTube.ContentIntelligence.TrendingTopicAnalyzer do
  @moduledoc """
  Trending topic analysis for YouTube content intelligence.

  Provides search momentum scoring, saturation index, and
  evergreen vs viral classification.
  """

  @doc """
  Analyzes trending topics for content opportunities.

  ## Parameters

    * `search_queries` - List of search query strings
    * `trending_data` - Map of topic to trending score
    * `channel_niche` - Channel niche/topic category

  ## Returns

    * `{:ok, result}` - Trending analysis results
    * `{:error, reason}` - If input is invalid
  """
  def analyze(input) when is_map(input) do
    with {:ok, validated} <- validate_input(input) do
      momentum_scores = calculate_momentum_scores(validated.search_queries, validated.trending_data)
      saturation_index = calculate_saturation_index(validated.trending_data)
      classification = classify_content(validated.search_queries, validated.trending_data)

      {:ok, %{
        search_momentum: momentum_scores,
        saturation_index: saturation_index,
        content_classification: classification,
        evergreen_topics: filter_evergreen(momentum_scores),
        viral_topics: filter_viral(momentum_scores),
        recommended_opportunities: identify_opportunities(momentum_scores, saturation_index)
      }}
    end
  end

  def analyze(_input), do: {:error, :invalid_input}

  @doc """
  Calculates search momentum score for a topic (0-100).
  """
  def momentum_score(topic, trending_data) when is_binary(topic) and is_map(trending_data) do
    score = Map.get(trending_data, topic, 0)
    round(clamp(score, 0.0, 100.0))
  end

  def momentum_score(_, _), do: {:error, :invalid_input}

  @doc """
  Calculates saturation index (how saturated a topic is).
  """
  def saturation_index(trending_data) when is_map(trending_data) do
    calculate_saturation_index(trending_data)
  end

  def saturation_index(_), do: {:error, :invalid_input}

  @doc """
  Classifies content as evergreen or viral.
  """
  def classify(topic, trending_data) when is_binary(topic) and is_map(trending_data) do
    score = Map.get(trending_data, topic, 0)
    if score > 70 do
      "viral"
    else
      "evergreen"
    end
  end

  def classify(_, _), do: {:error, :invalid_input}

  # Private helpers

  defp validate_input(input) do
    required = [:search_queries, :trending_data, :channel_niche]

    missing = Enum.filter(required, fn key -> not Map.has_key?(input, key) end)

    if missing != [] do
      {:error, {:missing_fields, missing}}
    else
      cond do
        not is_list(input.search_queries) -> {:error, {:invalid_value, :search_queries}}
        not is_map(input.trending_data) -> {:error, {:invalid_value, :trending_data}}
        not is_binary(input.channel_niche) -> {:error, {:invalid_value, :channel_niche}}
        true -> {:ok, input}
      end
    end
  end

  defp calculate_momentum_scores(queries, trending_data) do
    Enum.map(queries, fn query ->
      score = Map.get(trending_data, query, 0)
      %{"query" => query, "momentum_score" => round(clamp(score, 0.0, 100.0))}
    end)
    |> Enum.sort_by(fn e -> -e["momentum_score"] end)
  end

  defp calculate_saturation_index(trending_data) do
    values = Map.values(trending_data)
    if values != [] do
      avg = Enum.sum(values) / length(values)
      round(clamp(avg, 0.0, 100.0))
    else
      0
    end
  end

  defp classify_content(queries, trending_data) do
    Enum.map(queries, fn query ->
      score = Map.get(trending_data, query, 0)
      classification = if score > 70, do: "viral", else: "evergreen"
      %{query: query, classification: classification, score: score}
    end)
  end

  defp filter_evergreen(momentum_scores) do
    Enum.filter(momentum_scores, fn e -> e["momentum_score"] <= 70 end)
  end

  defp filter_viral(momentum_scores) do
    Enum.filter(momentum_scores, fn e -> e["momentum_score"] > 70 end)
  end

  defp identify_opportunities(momentum_scores, saturation_index) do
    # High momentum + low saturation = good opportunity
    Enum.filter(momentum_scores, fn e ->
      e["momentum_score"] > 50 and saturation_index < 60
    end)
  end

  defp clamp(value, min_val, max_val) do
    min(max(value, min_val), max_val)
  end
end