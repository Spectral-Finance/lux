defmodule Lux.Prisms.YouTube.Intelligence.PerformancePredictor do
  @moduledoc """
  Prism for predicting video performance based on metadata, channel history,
  and trending patterns.

  Uses statistical models to estimate view counts, engagement rates,
  and optimal content characteristics.
  """

  use Lux.Prism,
    name: "YouTube Performance Predictor",
    description: "Predict video performance metrics based on content analysis",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        tags: %{type: :array},
        duration_minutes: %{type: :number},
        niche: %{type: :string},
        channel_subscribers: %{type: :integer},
        channel_avg_views: %{type: :integer},
        historical_videos: %{type: :array, description: "Past video performance data"}
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        predicted_views: %{type: :object},
        predicted_engagement: %{type: :object},
        confidence: %{type: :number},
        recommendations: %{type: :array}
      }
    }

  @impl true
  def handler(params, _opts) do
    title = params[:title] || params["title"] || ""
    tags = params[:tags] || params["tags"] || []
    duration = params[:duration_minutes] || params["duration_minutes"] || 10
    subs = params[:channel_subscribers] || params["channel_subscribers"] || 1000
    avg_views = params[:channel_avg_views] || params["channel_avg_views"] || subs * 0.1
    historical = params[:historical_videos] || params["historical_videos"] || []

    # Title quality score
    title_score = score_title(title)

    # SEO score
    seo_score = score_seo(title, params[:description] || "", tags)

    # Duration score (optimal: 8-15 minutes)
    duration_score = score_duration(duration)

    # Combined quality score
    quality = (title_score * 0.4 + seo_score * 0.3 + duration_score * 0.3) / 100

    # View prediction based on channel size + quality
    base_views = avg_views * 1.0
    predicted_low = round(base_views * quality * 0.5)
    predicted_mid = round(base_views * quality * 1.0)
    predicted_high = round(base_views * quality * 2.0)

    # Engagement prediction
    base_engagement = 3.5  # avg YouTube engagement rate
    engagement_modifier = quality * 1.5
    predicted_engagement = Float.round(base_engagement * engagement_modifier, 2)

    # Confidence based on data availability
    confidence =
      cond do
        length(historical) >= 10 -> 0.75
        length(historical) >= 5 -> 0.55
        subs > 0 -> 0.35
        true -> 0.20
      end

    recommendations = generate_recommendations(title_score, seo_score, duration_score, duration)

    {:ok, %{
      predicted_views: %{
        low: predicted_low,
        mid: predicted_mid,
        high: predicted_high
      },
      predicted_engagement: %{
        rate: predicted_engagement,
        estimated_likes: round(predicted_mid * predicted_engagement / 100 * 0.8),
        estimated_comments: round(predicted_mid * predicted_engagement / 100 * 0.2)
      },
      scores: %{
        title: title_score,
        seo: seo_score,
        duration: duration_score,
        overall: round(quality * 100)
      },
      confidence: confidence,
      recommendations: recommendations
    }}
  end

  defp score_title(title) do
    score = 30
    len = String.length(title)
    score = if len >= 40 and len <= 70, do: score + 20, else: score + 5
    score = if Regex.match?(~r/\d/, title), do: score + 15, else: score
    score = if String.contains?(title, "?") or String.contains?(title, "!"), do: score + 10, else: score
    score = if len > 0, do: score + 10, else: score

    power_words = ~w(how best top ultimate guide secret new free proven)
    score = if Enum.any?(power_words, &String.contains?(String.downcase(title), &1)), do: score + 15, else: score

    min(score, 100)
  end

  defp score_seo(title, description, tags) do
    score = 20
    score = if String.length(description) > 100, do: score + 20, else: score + 5
    score = if length(tags) >= 5, do: score + 20, else: score + (length(tags) * 4)
    score = if String.length(title) > 0 and length(tags) > 0 do
      # Check if any tags appear in title
      tag_in_title = Enum.any?(tags, fn tag ->
        String.contains?(String.downcase(title), String.downcase(to_string(tag)))
      end)
      if tag_in_title, do: score + 20, else: score + 5
    else
      score
    end
    score = if String.length(description) > 500, do: score + 10, else: score
    min(score, 100)
  end

  defp score_duration(duration) do
    cond do
      duration >= 8 and duration <= 15 -> 90
      duration >= 5 and duration <= 20 -> 75
      duration >= 3 and duration <= 30 -> 60
      duration > 30 -> 50
      true -> 40
    end
  end

  defp generate_recommendations(title_score, seo_score, duration_score, duration) do
    recs = []
    recs = if title_score < 60, do: ["Improve title: add numbers, power words, or make it a question" | recs], else: recs
    recs = if seo_score < 50, do: ["Add more tags and expand description for better SEO" | recs], else: recs
    recs = if duration_score < 70, do: ["Optimal duration is 8-15 minutes for most niches" | recs], else: recs
    recs = if duration < 3, do: ["Very short videos may not be recommended by YouTube's algorithm" | recs], else: recs
    recs = if duration > 30, do: ["Consider splitting into a multi-part series" | recs], else: recs
    if recs == [], do: ["Content looks well optimized!"], else: Enum.reverse(recs)
  end
end
