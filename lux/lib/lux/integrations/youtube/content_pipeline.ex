defmodule Lux.Integrations.YouTube.ContentPipeline do
  @moduledoc """
  Deterministic planning pipeline for YouTube content creation.

  The pipeline turns a content brief into a production-ready plan covering script
  structure, visual optimization, metadata, cards, end screens, playlists,
  localization, repurposing, and A/B tests. It does not call external services,
  so agents can run it during planning, review, and CI without YouTube
  credentials.
  """

  @required_fields [:topic, :target_audience, :goal]
  @default_languages ["en"]
  @default_duration 8

  @doc """
  Builds the full content creation pipeline from a brief.
  """
  @spec build(map()) :: {:ok, map()} | {:error, {:missing_fields, [atom()]}}
  def build(brief) when is_map(brief) do
    brief = normalize_brief(brief)

    case missing_fields(brief) do
      [] ->
        {:ok,
         %{
           brief: brief,
           script: script_plan(brief),
           editing: editing_plan(brief),
           visual_optimization: visual_optimization_plan(brief),
           metadata: metadata_plan(brief),
           playlist: playlist_plan(brief),
           localization: localization_plan(brief),
           repurposing: repurposing_plan(brief),
           testing: testing_plan(brief),
           handoff: handoff_plan(brief)
         }}

      fields ->
        {:error, {:missing_fields, fields}}
    end
  end

  def build(_brief), do: {:error, {:missing_fields, @required_fields}}

  @doc """
  Same as `build/1`, kept as the pipeline action name for agent workflows.
  """
  @spec run(map()) :: {:ok, map()} | {:error, {:missing_fields, [atom()]}}
  def run(brief), do: build(brief)

  @doc """
  Creates a script outline with hooks, sections, retention beats, and CTA.
  """
  @spec script_plan(map()) :: map()
  def script_plan(brief) do
    brief = normalize_brief(brief)
    topic = brief.topic
    audience = brief.target_audience
    goal = brief.goal
    duration = brief.duration_minutes
    sections = section_count(duration)

    %{
      working_title: "#{titleize(topic)} for #{audience}",
      hook: "Open with the specific pain point: #{topic}, then promise #{goal}.",
      intro: "State who this is for, what changes by the end, and why the viewer should keep watching.",
      sections:
        Enum.map(1..sections, fn index ->
          %{
            order: index,
            heading: section_heading(topic, index),
            talking_points: talking_points(topic, audience, index),
            visual_notes: [
              "Use a concrete screen, chart, or object while explaining this section.",
              "Add a pattern interrupt before minute #{index * max(div(duration, sections), 1)}."
            ],
            retention_prompt: retention_prompt(index, sections)
          }
        end),
      outro: "Recap the transformation, answer the likely objection, and bridge to the next video.",
      call_to_action: brief.cta,
      estimated_duration_minutes: duration,
      tone: brief.tone
    }
  end

  @doc """
  Produces automated editing and retention suggestions.
  """
  @spec editing_plan(map()) :: map()
  def editing_plan(brief) do
    brief = normalize_brief(brief)

    %{
      pacing: %{
        target_cut_interval_seconds: if(brief.duration_minutes > 10, do: 8, else: 6),
        cold_open_seconds: 12,
        intro_max_seconds: 35
      },
      timeline:
        script_plan(brief).sections
        |> Enum.map(fn section ->
          %{
            section: section.heading,
            edit: "Pair talking head with proof, b-roll, or screen capture.",
            retention_check: section.retention_prompt
          }
        end),
      b_roll: [
        "Show the before state in the first 20 seconds.",
        "Show concrete examples whenever a claim includes numbers or process steps.",
        "Use one visual reset before every major section."
      ],
      captions: %{
        style: "high-contrast burned-in captions for key claims",
        required_terms: brief.keywords
      },
      quality_checks: [
        "Remove repeated setup before the first payoff.",
        "Keep each section tied to the viewer goal: #{brief.goal}.",
        "Add a visual example anywhere the script says 'simple', 'easy', or 'best'."
      ]
    }
  end

  @doc """
  Builds thumbnail and on-screen visual optimization guidance.
  """
  @spec visual_optimization_plan(map()) :: map()
  def visual_optimization_plan(brief) do
    brief = normalize_brief(brief)
    topic = brief.topic

    %{
      thumbnail: %{
        variants: [
          thumbnail_variant("Outcome", topic, "#{short_goal(brief.goal)}", "result proof + expressive face"),
          thumbnail_variant("Tension", topic, "Before vs After", "split contrast with one visible metric"),
          thumbnail_variant("Curiosity", topic, "I tested this", "single bold object and minimal text")
        ],
        constraints: [
          "3 to 5 words maximum",
          "Readable at mobile feed size",
          "One focal subject, one promise, no clutter"
        ]
      },
      on_screen_graphics: [
        "Add chapter cards for each major script section.",
        "Use checklists for process-heavy explanations.",
        "Use progress markers when the video includes more than three steps."
      ],
      accessibility: [
        "Avoid color-only meaning in charts.",
        "Reserve safe margins for captions and platform overlays.",
        "Keep title-safe text away from the lower-right watermark area."
      ]
    }
  end

  @doc """
  Creates metadata, card, end screen, and chapter recommendations.
  """
  @spec metadata_plan(map()) :: map()
  def metadata_plan(brief) do
    brief = normalize_brief(brief)
    title = titleize(brief.topic)

    %{
      title_variants: [
        "#{title}: #{short_goal(brief.goal)}",
        "How to #{String.downcase(short_goal(brief.goal))} with #{title}",
        "#{title} explained for #{brief.target_audience}"
      ],
      description:
        "#{title} for #{brief.target_audience}. This video covers #{brief.goal}, key decisions, and next steps.",
      tags: Enum.take(unique_tags([brief.topic, brief.target_audience, brief.format | brief.keywords]), 15),
      chapters: chapter_plan(brief),
      cards: [
        %{placement: "25%", type: "video", purpose: "answer the first likely objection"},
        %{placement: "55%", type: "playlist", purpose: "continue the learning path"},
        %{placement: "80%", type: "video", purpose: "send ready viewers to implementation"}
      ],
      end_screen: %{
        primary_slot: "Best next video for #{brief.target_audience}",
        secondary_slot: "Playlist: #{playlist_name(brief)}",
        subscribe_prompt: "Subscribe for more #{brief.topic} workflows"
      }
    }
  end

  @doc """
  Recommends playlist placement and organization.
  """
  @spec playlist_plan(map()) :: map()
  def playlist_plan(brief) do
    brief = normalize_brief(brief)
    existing = brief.existing_playlists
    primary = matching_playlist(existing, brief) || playlist_name(brief)

    %{
      primary_playlist: primary,
      create_if_missing: is_nil(matching_playlist(existing, brief)),
      placement_reason: "Groups #{brief.topic} content for #{brief.target_audience} and supports session depth.",
      ordering: [
        "Place after the beginner overview if one exists.",
        "Place before advanced troubleshooting or case-study videos.",
        "Link back from adjacent videos with cards."
      ],
      related_playlists: Enum.take(existing -- [primary], 3)
    }
  end

  @doc """
  Creates localization tasks for requested languages.
  """
  @spec localization_plan(map()) :: map()
  def localization_plan(brief) do
    brief = normalize_brief(brief)

    %{
      default_language: List.first(brief.languages),
      languages:
        Enum.map(brief.languages, fn language ->
          %{
            language: language,
            title_task: "Localize the strongest title variant for #{language}.",
            description_task: "Adapt the description with local search terms and cultural examples.",
            subtitle_task: "Create subtitles and review domain terms: #{Enum.join(brief.keywords, ", ")}.",
            thumbnail_task: "Check thumbnail text length and readability for #{language}."
          }
        end)
    }
  end

  @doc """
  Plans derivative assets for shorts, social, newsletters, and articles.
  """
  @spec repurposing_plan(map()) :: map()
  def repurposing_plan(brief) do
    brief = normalize_brief(brief)

    %{
      shorts:
        script_plan(brief).sections
        |> Enum.take(3)
        |> Enum.map(fn section ->
          %{
            source_section: section.heading,
            hook: section.retention_prompt,
            duration_seconds: 35,
            caption: "#{section.heading}: #{short_goal(brief.goal)}"
          }
        end),
      social_posts: [
        "Problem post: why #{brief.topic} matters for #{brief.target_audience}.",
        "Process post: the three decisions from the video.",
        "Result post: what changes after applying #{brief.goal}."
      ],
      newsletter: %{
        subject: "#{titleize(brief.topic)}: the practical version",
        outline: ["Problem", "Method", "Checklist", "Watch link"]
      },
      blog_outline: [
        "Introduction",
        "Core framework",
        "Examples",
        "Checklist",
        "Video embed and next steps"
      ]
    }
  end

  @doc """
  Designs A/B tests for titles, thumbnails, and calls to action.
  """
  @spec testing_plan(map()) :: map()
  def testing_plan(brief) do
    brief = normalize_brief(brief)
    metadata = metadata_plan(brief)
    thumbnail = visual_optimization_plan(brief).thumbnail

    %{
      experiments: [
        %{
          name: "title promise",
          variants: Enum.take(metadata.title_variants, 2),
          primary_metric: "impressions click-through rate",
          guardrail_metric: "average view duration",
          min_runtime_days: 7,
          winner_rule: "Choose the title with higher CTR if retention stays within 5%."
        },
        %{
          name: "thumbnail angle",
          variants: Enum.map(thumbnail.variants, & &1.name),
          primary_metric: "browse CTR",
          guardrail_metric: "first 30 second retention",
          min_runtime_days: 7,
          winner_rule: "Choose the variant that improves CTR without a retention drop."
        },
        %{
          name: "call to action",
          variants: [brief.cta, "Watch the next video in #{playlist_name(brief)}"],
          primary_metric: "end screen click rate",
          guardrail_metric: "subscriber conversion",
          min_runtime_days: 14,
          winner_rule: "Keep the CTA with stronger downstream clicks."
        }
      ],
      sample_notes: [
        "Run tests only after the video has stable impressions.",
        "Do not change title and thumbnail at the same time unless this is a packaged test.",
        "Record publish date, variant, impressions, CTR, retention, and end screen clicks."
      ]
    }
  end

  @doc """
  Creates a final production handoff checklist.
  """
  @spec handoff_plan(map()) :: map()
  def handoff_plan(brief) do
    brief = normalize_brief(brief)

    %{
      assets: brief.assets,
      owners: %{
        script: "writer",
        edit: "editor",
        thumbnail: "designer",
        metadata: "channel manager",
        localization: "localization reviewer"
      },
      publish_checklist: [
        "Script approved against goal: #{brief.goal}",
        "Thumbnail variant selected and exported",
        "Title, description, tags, chapters, cards, and end screen configured",
        "Playlist placement confirmed",
        "Repurposed assets queued",
        "A/B test sheet initialized"
      ]
    }
  end

  defp normalize_brief(brief) do
    %{
      topic: fetch_string(brief, :topic),
      target_audience: fetch_string(brief, :target_audience),
      goal: fetch_string(brief, :goal),
      tone: fetch_string(brief, :tone, "clear and practical"),
      format: fetch_string(brief, :format, "tutorial"),
      duration_minutes: brief |> fetch(:duration_minutes, @default_duration) |> parse_positive_int(@default_duration),
      keywords: brief |> fetch(:keywords, []) |> list_of_strings() |> ensure_keywords(fetch_string(brief, :topic)),
      languages:
        brief
        |> fetch(:languages, @default_languages)
        |> list_of_strings()
        |> default_if_empty(@default_languages),
      brand_voice: fetch_string(brief, :brand_voice, "credible, concise, and useful"),
      channel_name: fetch_string(brief, :channel_name, "YouTube channel"),
      cta: fetch_string(brief, :cta, "Watch the next video and subscribe for future workflows."),
      existing_playlists: brief |> fetch(:existing_playlists, []) |> list_of_strings(),
      assets: brief |> fetch(:assets, []) |> list_of_strings(),
      source_content: fetch_string(brief, :source_content, ""),
      publishing_window: fetch_string(brief, :publishing_window, "next available high-retention window")
    }
  end

  defp missing_fields(brief) do
    Enum.filter(@required_fields, &(Map.get(brief, &1) == ""))
  end

  defp section_count(duration) when duration <= 6, do: 3
  defp section_count(duration) when duration <= 12, do: 4
  defp section_count(_duration), do: 5

  defp section_heading(topic, index) do
    case index do
      1 -> "Why #{topic} matters"
      2 -> "The practical framework"
      3 -> "Step-by-step execution"
      4 -> "Common mistakes and fixes"
      _ -> "Next actions and scale-up path"
    end
  end

  defp talking_points(topic, audience, index) do
    [
      "Tie #{topic} to a concrete #{audience} outcome.",
      "Show the decision or action for step #{index}.",
      "Name the tradeoff and the reason behind the recommendation."
    ]
  end

  defp retention_prompt(index, total) when index == total do
    "Promise a practical next step before the final CTA."
  end

  defp retention_prompt(index, _total) do
    "Tease section #{index + 1} with a specific payoff."
  end

  defp thumbnail_variant(name, topic, text, composition) do
    %{
      name: name,
      text_overlay: text,
      subject: topic,
      composition: composition,
      test_hypothesis: "#{name} angle increases qualified clicks."
    }
  end

  defp chapter_plan(brief) do
    brief
    |> script_plan()
    |> Map.fetch!(:sections)
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      %{
        timestamp: minute_mark(index, brief.duration_minutes),
        title: section.heading
      }
    end)
  end

  defp minute_mark(index, duration) do
    minutes = min(index * max(div(duration, max(section_count(duration), 1)), 1), max(duration - 1, 0))
    "#{minutes}:00"
  end

  defp matching_playlist([], _brief), do: nil

  defp matching_playlist(playlists, brief) do
    topic = String.downcase(brief.topic)
    audience = String.downcase(brief.target_audience)
    keywords = Enum.map(brief.keywords, &String.downcase/1)

    Enum.find(playlists, fn playlist ->
      playlist = String.downcase(playlist)
      String.contains?(playlist, topic) or String.contains?(playlist, audience) or
        Enum.any?(keywords, &String.contains?(playlist, &1))
    end)
  end

  defp playlist_name(brief), do: "#{titleize(brief.topic)} for #{brief.target_audience}"

  defp titleize(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp short_goal(goal) do
    goal
    |> to_string()
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(6)
    |> Enum.join(" ")
  end

  defp unique_tags(values) do
    values
    |> List.wrap()
    |> Enum.flat_map(fn value ->
      value
      |> to_string()
      |> String.split([",", ";"], trim: true)
    end)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq_by(&String.downcase/1)
  end

  defp ensure_keywords([], topic), do: unique_tags([topic])
  defp ensure_keywords(keywords, _topic), do: keywords

  defp default_if_empty([], default), do: default
  defp default_if_empty(values, _default), do: values

  defp fetch_string(map, key, default \\ "") do
    map
    |> fetch(key, default)
    |> to_string()
    |> String.trim()
  end

  defp fetch(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp list_of_strings(value) when is_list(value) do
    value
    |> Enum.map(&(to_string(&1) |> String.trim()))
    |> Enum.reject(&(&1 == ""))
  end

  defp list_of_strings(value) when value in [nil, ""], do: []
  defp list_of_strings(value), do: [to_string(value)]

  defp parse_positive_int(value, _default) when is_integer(value) and value > 0, do: value

  defp parse_positive_int(value, default) do
    case Integer.parse(to_string(value)) do
      {integer, _rest} when integer > 0 -> integer
      _ -> default
    end
  end
end
