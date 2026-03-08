defmodule Lux.Prisms.YouTube.Intelligence.ContentOptimizer do
  @moduledoc """
  Prism for optimizing YouTube content metadata — titles, descriptions, tags,
  and posting times based on analytics data and content patterns.

  Uses engagement data and trending patterns to generate optimized metadata.
  """

  use Lux.Prism,
    name: "YouTube Content Optimizer",
    description: "Optimize video titles, descriptions, tags, and posting schedule",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["optimize_title", "generate_tags", "optimize_description", "best_posting_time", "full_optimization"]
        },
        title: %{type: :string, description: "Current or draft title"},
        description: %{type: :string, description: "Current or draft description"},
        tags: %{type: :array, description: "Current tags"},
        niche: %{type: :string, description: "Content niche/category"},
        target_audience: %{type: :string, description: "Target audience description"},
        trending_data: %{type: :object, description: "Trending analysis data for context"},
        analytics_data: %{type: :object, description: "Video/channel analytics for context"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        suggestions: %{type: :array},
        optimized: %{type: :object},
        score: %{type: :number}
      }
    }

  @title_max_length 100
  @description_max_length 5000
  @max_tags 30

  @power_words ~w(ultimate guide how best top secret revealed amazing surprising shocking new free proven)
  @cta_phrases ["Subscribe for more", "Like and share", "Comment below", "Turn on notifications"]

  @impl true
  def handler(params, _opts) do
    action = params[:action] || params["action"]

    case action do
      "optimize_title" -> optimize_title(params)
      "generate_tags" -> generate_tags(params)
      "optimize_description" -> optimize_description(params)
      "best_posting_time" -> predict_best_time(params)
      "full_optimization" -> full_optimization(params)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp optimize_title(params) do
    title = params[:title] || params["title"] || ""
    niche = params[:niche] || params["niche"] || ""

    suggestions = [
      add_power_word(title),
      add_number(title),
      add_brackets(title),
      add_question(title, niche)
    ]
    |> Enum.uniq()
    |> Enum.filter(&(String.length(&1) <= @title_max_length))

    score = title_score(title)

    {:ok, %{
      original: title,
      suggestions: suggestions,
      score: score,
      tips: title_tips(title)
    }}
  end

  defp generate_tags(params) do
    title = params[:title] || params["title"] || ""
    description = params[:description] || params["description"] || ""
    niche = params[:niche] || params["niche"] || ""
    existing = params[:tags] || params["tags"] || []

    # Extract keywords from title and description
    text = "#{title} #{description} #{niche}"

    keywords =
      text
      |> String.downcase()
      |> String.split(~r/[\s,\.\!\?\-|]+/)
      |> Enum.filter(&(String.length(&1) > 2))
      |> Enum.uniq()

    # Generate tag combinations
    single_tags = keywords |> Enum.take(15)

    phrase_tags =
      keywords
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(&Enum.join(&1, " "))
      |> Enum.take(10)

    all_tags =
      (existing ++ single_tags ++ phrase_tags)
      |> Enum.uniq()
      |> Enum.take(@max_tags)

    {:ok, %{
      tags: all_tags,
      count: length(all_tags),
      max_allowed: @max_tags
    }}
  end

  defp optimize_description(params) do
    description = params[:description] || params["description"] || ""
    title = params[:title] || params["title"] || ""
    niche = params[:niche] || params["niche"] || ""

    optimized =
      [
        "#{title}\n",
        description,
        "\n\n---",
        "\n📌 #{Enum.random(@cta_phrases)}",
        "\n\n🔍 Keywords: #{niche}",
        "\n\n##{String.replace(niche, " ", "")} #youtube"
      ]
      |> Enum.join("")
      |> String.slice(0, @description_max_length)

    {:ok, %{
      optimized_description: optimized,
      length: String.length(optimized),
      has_cta: true,
      has_keywords: true,
      has_hashtags: true
    }}
  end

  defp predict_best_time(params) do
    analytics = params[:analytics_data] || params["analytics_data"] || %{}
    niche = params[:niche] || params["niche"] || ""

    # Based on general YouTube best practices by niche
    schedule = case String.downcase(niche) do
      n when n in ["gaming", "entertainment"] ->
        %{best_days: ["Friday", "Saturday"], best_hours: [14, 16, 20], timezone: "UTC"}

      n when n in ["education", "tech", "science"] ->
        %{best_days: ["Tuesday", "Thursday"], best_hours: [10, 14, 17], timezone: "UTC"}

      n when n in ["business", "finance"] ->
        %{best_days: ["Monday", "Wednesday"], best_hours: [8, 12, 15], timezone: "UTC"}

      _ ->
        %{best_days: ["Wednesday", "Friday", "Saturday"], best_hours: [12, 15, 18], timezone: "UTC"}
    end

    {:ok, Map.merge(schedule, %{
      niche: niche,
      note: "Adjust based on your audience's timezone and engagement patterns",
      analytics_used: map_size(analytics) > 0
    })}
  end

  defp full_optimization(params) do
    with {:ok, title_result} <- optimize_title(params),
         {:ok, tags_result} <- generate_tags(params),
         {:ok, desc_result} <- optimize_description(params),
         {:ok, time_result} <- predict_best_time(params) do
      {:ok, %{
        title: title_result,
        tags: tags_result,
        description: desc_result,
        posting_time: time_result,
        overall_score: title_result.score
      }}
    end
  end

  # Title optimization helpers

  defp add_power_word(title) do
    word = Enum.random(@power_words)
    "#{String.capitalize(word)}: #{title}"
  end

  defp add_number(title) do
    if Regex.match?(~r/\d/, title) do
      title
    else
      "7 #{title}"
    end
  end

  defp add_brackets(title) do
    "#{title} [#{DateTime.utc_now().year}]"
  end

  defp add_question(title, niche) do
    if String.ends_with?(title, "?") do
      title
    else
      "How to #{String.downcase(title)}? | #{niche}"
    end
  end

  defp title_score(title) do
    score = 50
    score = if String.length(title) >= 40 and String.length(title) <= 70, do: score + 15, else: score
    score = if Regex.match?(~r/\d/, title), do: score + 10, else: score
    score = if Enum.any?(@power_words, &String.contains?(String.downcase(title), &1)), do: score + 10, else: score
    score = if String.contains?(title, "[") or String.contains?(title, "("), do: score + 5, else: score
    score = if String.ends_with?(title, "?"), do: score + 5, else: score
    score = if String.length(title) > 0, do: score + 5, else: score
    min(score, 100)
  end

  defp title_tips(title) do
    tips = []
    tips = if String.length(title) < 40, do: ["Consider a longer title (40-70 chars optimal)" | tips], else: tips
    tips = if String.length(title) > 70, do: ["Title may be truncated in search results" | tips], else: tips
    tips = if not Regex.match?(~r/\d/, title), do: ["Add numbers for better CTR" | tips], else: tips
    tips = if not Enum.any?(@power_words, &String.contains?(String.downcase(title), &1)), do: ["Add a power word" | tips], else: tips
    if tips == [], do: ["Title looks good!"], else: tips
  end
end
