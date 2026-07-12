defmodule Lux.YouTube.Prisms.MetadataOptimizationPrism do
  @moduledoc """
  Generates and optimizes metadata such as titles, tags, and descriptions for YouTube videos.
  NOTE: This is a deterministic heuristic baseline model, not a true ML prediction model.
  """
  use Lux.Prism,
    name: "MetadataOptimizationPrism",
    description: "Optimizes title, tags, description and suggests posting times",
    input_schema: %{
      type: "object",
      properties: %{
        "topic" => %{
          type: "string",
          description: "The main topic or keyword of the video"
        },
        "target_audience" => %{
          type: "string",
          description: "The intended demographic or audience"
        },
        "audience_timezone" => %{
          type: "string",
          description: "Primary timezone of the audience"
        },
        "trend_evidence" => %{
          type: "string",
          description: "Evidence of trending days or posting patterns"
        }
      },
      required: ["topic"]
    },
    capabilities: [
      "optimize_title_thumbnail",
      "optimize_tags",
      "generate_description",
      "predict_posting_time"
    ]

  def handler(%{"topic" => topic} = input, _context) do
    audience = Map.get(input, "target_audience", "general audience")
    timezone = Map.get(input, "audience_timezone", "EST")
    trends = Map.get(input, "trend_evidence", "Wednesday, Friday, Saturday")

    # Deterministic baseline model (not a true ML model)
    titles =
      [
        "#{String.capitalize(topic)}: The Ultimate Guide for #{audience}",
        "I Tried #{topic} and This Happened...",
        "What You Need to Know About #{topic} in 2026"
      ]
      |> Enum.map(&String.slice(&1, 0, 100)) # YouTube 100 char limit

    tags =
      topic
      |> String.downcase()
      |> String.split()
      |> Enum.map(&String.trim(&1, ","))
      |> Enum.concat(["viral", "trending", "tutorial", "guide", audience])
      |> Enum.uniq()
      |> Enum.take(15)

    tags_joined = Enum.join(tags, " #")

    description =
      """
      In this video, we dive deep into #{topic}.
      Perfect for #{audience} looking to understand the latest trends and techniques.

      Don't forget to like, subscribe, and hit the bell icon!

      # #{tags_joined}
      """
      |> String.slice(0, 5000) # YouTube 5000 char limit

    trend_days =
      trends
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    posting_times =
      case trend_days do
        [] -> ["Default peak hours in #{timezone}"]
        days -> Enum.map(days, &"#{&1} peak hours in #{timezone}")
      end

    {:ok,
     %{
       optimized_titles: titles,
       suggested_tags: tags,
       generated_description: description,
       optimal_posting_times: posting_times,
       thumbnail_ideas: [
         "High contrast text overlay with expressive face",
         "Before and after split screen",
         "Minimalist design with bold #{topic} graphic"
       ],
       model: "deterministic_baseline_v1"
     }}
  end
end
