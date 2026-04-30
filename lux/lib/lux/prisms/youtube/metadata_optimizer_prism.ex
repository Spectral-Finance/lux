defmodule Lux.Prisms.Youtube.MetadataOptimizerPrism do
  @moduledoc """
  A prism that optimizes YouTube video metadata for SEO and discoverability.

  Generates optimized titles, descriptions, tags, and category suggestions
  based on video content, competitor analysis, and search trends.

  ## Examples

      iex> Lux.Prisms.Youtube.MetadataOptimizerPrism.run(%{
      ...>   topic: "DeFi Dashboard Tutorial",
      ...>   existing_title: "My Video About DeFi",
      ...>   existing_description: "Watch this video",
      ...>   target_keywords: ["defi", "dashboard", "tutorial"]
      ...> })
      {:ok, %{optimized_title: "...", description: "...", tags: [...]}}
  """

  use Lux.Prism,
    name: "YouTube Metadata Optimizer",
    description: "Optimizes YouTube video metadata (title, description, tags) for SEO and discoverability",
    input_schema: %{
      type: :object,
      properties: %{
        topic: %{
          type: :string,
          description: "Main topic of the video"
        },
        existing_title: %{
          type: :string,
          description: "Current or draft video title"
        },
        existing_description: %{
          type: :string,
          description: "Current or draft video description"
        },
        target_keywords: %{
          type: :array,
          items: %{type: :string},
          description: "Target keywords for SEO"
        },
        category: %{
          type: :string,
          description: "YouTube category ID",
          default: "28"
        },
        language: %{
          type: :string,
          description: "Video language code",
          default: "en"
        },
        include_timestamps: %{
          type: :boolean,
          description: "Include chapter timestamps in description",
          default: true
        }
      },
      required: ["topic"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        optimized_title: %{type: :string},
        title_alternatives: %{type: :array},
        optimized_description: %{type: :string},
        tags: %{type: :array},
        category_suggestion: %{type: :string},
        seo_score: %{type: :number},
        recommendations: %{type: :array}
      }
    }

  @max_title_length 60
  @max_description_length 5000
  @max_tags 500

  @doc """
  Optimizes YouTube video metadata.
  """
  def run(params) do
    topic = Map.get(params, :topic, params["topic"])
    existing_title = Map.get(params, :existing_title, params["existing_title"] || "")
    existing_description = Map.get(params, :existing_description, params["existing_description"] || "")
    target_keywords = Map.get(params, :target_keywords, params["target_keywords"] || [])
    category = Map.get(params, :category, params["category"] || "28")
    language = Map.get(params, :language, params["language"] || "en")
    include_timestamps = Map.get(params, :include_timestamps, params["include_timestamps"] || true)

    # Generate optimized title
    optimized_title = generate_optimized_title(topic, existing_title, target_keywords)
    title_alternatives = generate_title_alternatives(topic, target_keywords)

    # Generate optimized description
    optimized_description = generate_optimized_description(%{
      topic: topic,
      existing_description: existing_description,
      optimized_title: optimized_title,
      target_keywords: target_keywords,
      include_timestamps: include_timestamps
    })

    # Generate tags
    tags = generate_tags(topic, target_keywords, existing_title)

    # Calculate SEO score
    seo_score = calculate_seo_score(%{
      title: optimized_title,
      description: optimized_description,
      tags: tags,
      target_keywords: target_keywords
    })

    # Generate recommendations
    recommendations = generate_recommendations(%{
      title: optimized_title,
      description: optimized_description,
      tags: tags,
      seo_score: seo_score
    })

    result = %{
      optimized_title: optimized_title,
      title_alternatives: title_alternatives,
      optimized_description: optimized_description,
      tags: tags,
      category_suggestion: suggest_category(category),
      seo_score: seo_score,
      recommendations: recommendations
    }

    {:ok, result}
  end

  defp generate_optimized_title(topic, existing_title, keywords) do
    # If existing title is good, enhance it; otherwise generate new one
    if String.length(existing_title) > 0 and String.length(existing_title) <= @max_title_length do
      # Enhance existing title with keywords
      enhance_title(existing_title, keywords)
    else
      # Generate new title
      generate_new_title(topic, keywords)
    end
  end

  defp enhance_title(title, []) do
    title |> String.trim() |> String.slice(0, @max_title_length)
  end

  defp enhance_title(title, [keyword | _rest]) do
    if String.downcase(title) |> String.contains?(String.downcase(keyword)) do
      title |> String.trim() |> String.slice(0, @max_title_length)
    else
      "#{title} | #{keyword}" |> String.trim() |> String.slice(0, @max_title_length)
    end
  end

  defp generate_new_title(topic, []) do
    "#{topic} - Complete Guide" |> String.slice(0, @max_title_length)
  end

  defp generate_new_title(topic, [keyword | _]) do
    titles = [
      "#{topic} - Complete #{keyword} Guide",
      "How to #{topic} | #{keyword} Tutorial",
      "#{keyword}: #{topic} Explained",
      "The Ultimate #{topic} Guide (#{keyword})"
    ]
    Enum.random(titles) |> String.slice(0, @max_title_length)
  end

  defp generate_title_alternatives(topic, keywords) do
    kw = if length(keywords) > 0, do: Enum.at(keywords, 0), else: ""

    alternatives = [
      "#{topic} #{if kw != "", do: "| #{kw} Complete Guide", else: "- Full Tutorial}",
      "How to #{topic} #{if kw != "", do: "(#{kw} Tutorial)", else: ""}",
      "#{topic} for Beginners #{if kw != "", do: "| #{kw}", else: ""}",
      "#{topic} #{if kw != "", do: kw, else: "Explained"} - Step by Step",
      "Master #{topic} #{if kw != "", do: "| #{kw} Tips", else: "in 10 Minutes}"
    ]

    Enum.filter(alternatives, fn t ->
      String.length(t) <= @max_title_length and String.length(t) > 10
    end)
  end

  defp generate_optimized_description(params) do
    %{
      topic: topic,
      existing_description: existing_desc,
      optimized_title: title,
      target_keywords: keywords,
      include_timestamps: include_ts
    } = params

    # Build description
    desc_lines = []

    # Hook paragraph
    desc_lines = ["📌 #{title}\n\n" | desc_lines]

    # Main description
    main_desc = if String.length(existing_desc) > 20 do
      existing_desc
    else
      "In this video, we explore #{topic}. Whether you're a beginner or experienced, " <>
      "this comprehensive guide covers everything you need to know."
    end
    desc_lines = [main_desc | desc_lines]

    # Keywords section
    if length(keywords) > 0 do
      desc_lines = ["\n🔑 Keywords: #{Enum.join(keywords, ", ")}" | desc_lines]
    else
      desc_lines
    end

    # Timestamps
    if include_ts do
      desc_lines = [
        "\n⏰ Chapters:\n",
        "0:00 - Introduction\n",
        "1:00 - Getting Started\n",
        "3:00 - Main Content\n",
        "7:00 - Advanced Tips\n",
        "9:00 - Summary & Next Steps\n" | desc_lines
      ]
    else
      desc_lines
    end

    # CTA
    desc_lines = [
      "\n👍 If you found this helpful, please like and subscribe!\n",
      "🔔 Turn on notifications for more content like this.\n",
      "💬 Leave a comment with your questions or feedback." | desc_lines
    ]

    desc_lines
    |> Enum.reverse()
    |> Enum.join()
    |> String.slice(0, @max_description_length)
  end

  defp generate_tags(topic, keywords, existing_title) do
    tags = []

    # Add topic as tag
    tags = [topic | tags]

    # Add keywords
    tags = tags ++ keywords

    # Add variations
    tags = tags ++ [
      "#{topic} tutorial",
      "#{topic} guide",
      "#{topic} explained",
      "#{topic} for beginners"
    ]

    # Add title words (if meaningful)
    if String.length(existing_title) > 10 do
      title_words = existing_title
      |> String.split(~r/[^a-zA-Z0-9]/)
      |> Enum.filter(&(&1 |> String.length() > 3))
      |> Enum.take(5)
      tags = tags ++ title_words
    else
      tags
    end

    # Deduplicate and limit
    tags
    |> Enum.uniq()
    |> Enum.filter(&(&1 |> String.length() > 2))
    |> Enum.take(@max_tags)
  end

  defp calculate_seo_score(params) do
    %{title: title, description: desc, tags: tags, target_keywords: keywords} = params

    score = 0.0

    # Title length score (optimal: 50-60 chars)
    title_score = case String.length(title) do
      len when len >= 50 and len <= 60 -> 1.0
      len when len >= 30 and len < 50 -> 0.7
      len when len > 60 -> 0.5
      _ -> 0.3
    end

    # Keyword in title score
    keyword_title_score = if length(keywords) > 0 do
      title_lower = String.downcase(title)
      if Enum.any?(keywords, &String.contains?(title_lower, String.downcase(&1))), do: 1.0, else: 0.0
    else
      0.5
    end

    # Description length score
    desc_score = case String.length(desc) do
      len when len >= 200 -> 1.0
      len when len >= 100 -> 0.7
      len when len > 0 -> 0.4
      _ -> 0.0
    end

    # Tags score
    tag_score = case length(tags) do
      count when count >= 10 -> 1.0
      count when count >= 5 -> 0.7
      count when count > 0 -> 0.4
      _ -> 0.0
    end

    # Keyword coverage score
    keyword_coverage = if length(keywords) > 0 do
      desc_lower = String.downcase(desc)
      covered = Enum.count(keywords, &String.contains?(desc_lower, String.downcase(&1)))
      covered / length(keywords)
    else
      0.5
    end

    # Weighted average
    (title_score * 0.25 + keyword_title_score * 0.25 + desc_score * 0.2 + tag_score * 0.15 + keyword_coverage * 0.15)
    |> Float.round(2)
  end

  defp generate_recommendations(params) do
    %{title: title, description: desc, tags: tags, seo_score: score} = params

    recommendations = []

    recommendations = if String.length(title) < 50 do
      ["Title is too short. Aim for 50-60 characters for optimal display." | recommendations]
    else
      recommendations
    end

    recommendations = if String.length(desc) < 200 do
      ["Description is too short. Add at least 200 characters with keywords." | recommendations]
    else
      recommendations
    end

    recommendations = if length(tags) < 10 do
      ["Add more tags (aim for 10-15) to improve discoverability." | recommendations]
    else
      recommendations
    end

    recommendations = if score < 0.7 do
      ["SEO score is below 0.7. Review keyword placement in title and description." | recommendations]
    else
      recommendations
    end

    recommendations = [
      "Add custom thumbnail with high contrast and readable text.",
      "Include end screen with links to related videos.",
      "Use YouTube Cards to link to relevant content during the video."
    ] ++ recommendations

    recommendations
  end

  defp suggest_category(category_id) do
    categories = %{
      "1" => "Film & Animation",
      "2" => "Autos & Vehicles",
      "10" => "Music",
      "15" => "Pets & Animals",
      "17" => "Sports",
      "19" => "Travel & Events",
      "20" => "Gaming",
      "22" => "People & Blogs",
      "23" => "Comedy",
      "24" => "Entertainment",
      "25" => "News & Politics",
      "26" => "Howto & Style",
      "27" => "Education",
      "28" => "Science & Technology",
      "29" => "Nonprofits & Activism"
    }

    Map.get(categories, category_id, "Science & Technology")
  end
end
