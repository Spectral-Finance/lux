defmodule Lux.Integrations.YouTube.ContentPipeline do
  @moduledoc """
  YouTube content creation pipeline helpers.

  The module turns a content brief into script structure, editing suggestions,
  thumbnail briefs, metadata plans, playlist placement, localization tasks,
  repurposing ideas, and A/B test plans.
  """

  @doc """
  Builds a script outline from a content brief.
  """
  @spec script_outline(map()) :: map()
  def script_outline(brief) when is_map(brief) do
    topic = value(brief, :topic) || "Untitled topic"
    audience = value(brief, :audience) || "general audience"
    goal = value(brief, :goal) || "educate"

    %{
      hook: value(brief, :hook) || "Show why #{topic} matters to #{audience}.",
      intro: "Set context for #{topic} and promise the #{goal} outcome.",
      sections: sections(value(brief, :key_points) || [], topic),
      call_to_action: value(brief, :call_to_action) || "Ask viewers to comment with their next question.",
      estimated_minutes: estimate_minutes(value(brief, :key_points) || [])
    }
  end

  @doc """
  Suggests edits from script and retention targets.
  """
  @spec editing_suggestions(map()) :: [map()]
  def editing_suggestions(attrs) when is_map(attrs) do
    []
    |> add_edit(:intro_trim, number(attrs, :intro_seconds) > 20, "Trim intro below 20 seconds")
    |> add_edit(:pattern_interrupts, number(attrs, :estimated_minutes) > 6, "Add visual reset every 45-60 seconds")
    |> add_edit(:chapter_markers, length(value(attrs, :sections) || []) >= 3, "Add chapter markers for each major section")
    |> add_edit(:b_roll, value(attrs, :needs_visual_examples) == true, "Add b-roll or screen capture for abstract points")
    |> Enum.reverse()
  end

  @doc """
  Builds a thumbnail creative brief.
  """
  @spec thumbnail_brief(map()) :: map()
  def thumbnail_brief(attrs) when is_map(attrs) do
    topic = value(attrs, :topic) || "Video topic"

    %{
      concept: value(attrs, :concept) || "Before/after contrast for #{topic}",
      focal_text: attrs |> value(:focal_text) |> fallback(short_title(topic)),
      visual_elements: value(attrs, :visual_elements) || ["clear subject", "high contrast background", "one outcome cue"],
      avoid: value(attrs, :avoid) || ["small text", "crowded layout", "ambiguous emotion"],
      variants: thumbnail_variants(topic)
    }
  end

  @doc """
  Creates a metadata plan for title, description, tags, cards, and end screens.
  """
  @spec metadata_plan(map()) :: map()
  def metadata_plan(attrs) when is_map(attrs) do
    topic = value(attrs, :topic) || "Untitled"
    keywords = value(attrs, :keywords) || []

    %{
      title: attrs |> value(:title) |> fallback(short_title(topic)),
      description: description(topic, value(attrs, :summary), keywords),
      tags: keywords |> Enum.map(&normalize_tag/1) |> Enum.uniq() |> Enum.take(15),
      cards: value(attrs, :cards) || [],
      end_screen: value(attrs, :end_screen) || %{type: :next_video, label: "Watch next"}
    }
  end

  @doc """
  Plans playlist placement from content pillars.
  """
  @spec playlist_plan(map()) :: map()
  def playlist_plan(attrs) when is_map(attrs) do
    pillar = value(attrs, :pillar) || "General"

    %{
      playlist: value(attrs, :playlist) || pillar,
      position: value(attrs, :position) || :end,
      rationale: "Group with #{pillar} videos to improve session continuity"
    }
  end

  @doc """
  Builds localization tasks for requested languages.
  """
  @spec localization_tasks(map()) :: [map()]
  def localization_tasks(attrs) when is_map(attrs) do
    languages = value(attrs, :languages) || []

    Enum.map(languages, fn language ->
      %{
        language: language,
        tasks: [:translate_title, :translate_description, :translate_captions, :review_cultural_context],
        owner: value(attrs, :owner)
      }
    end)
  end

  @doc """
  Suggests ways to repurpose long-form content.
  """
  @spec repurposing_ideas(map()) :: [map()]
  def repurposing_ideas(attrs) when is_map(attrs) do
    topic = value(attrs, :topic) || "topic"

    [
      %{format: :short, idea: "Turn the strongest hook from #{topic} into a vertical short"},
      %{format: :thread, idea: "Summarize the key steps from #{topic} as a social thread"},
      %{format: :newsletter, idea: "Expand the checklist from #{topic} into a newsletter section"}
    ]
  end

  @doc """
  Creates an A/B test plan for title and thumbnail variants.
  """
  @spec ab_test_plan(map()) :: map()
  def ab_test_plan(attrs) when is_map(attrs) do
    %{
      metric: value(attrs, :metric) || :click_through_rate,
      minimum_runtime_hours: value(attrs, :minimum_runtime_hours) || 24,
      variants: [
        %{id: "A", title: value(attrs, :title_a) || value(attrs, :title), thumbnail: value(attrs, :thumbnail_a)},
        %{id: "B", title: value(attrs, :title_b) || alternate_title(value(attrs, :title)), thumbnail: value(attrs, :thumbnail_b)}
      ],
      decision_rule: value(attrs, :decision_rule) || "Choose the variant with higher CTR after minimum runtime"
    }
  end

  @doc """
  Builds the full content creation pipeline for a brief.
  """
  @spec pipeline(map()) :: map()
  def pipeline(brief) when is_map(brief) do
    outline = script_outline(brief)

    %{
      script: outline,
      editing: editing_suggestions(Map.merge(brief, outline)),
      thumbnail: thumbnail_brief(brief),
      metadata: metadata_plan(brief),
      playlist: playlist_plan(brief),
      localization: localization_tasks(brief),
      repurposing: repurposing_ideas(brief),
      ab_test: ab_test_plan(brief)
    }
  end

  defp sections([], topic) do
    [
      %{title: "Problem", prompt: "Explain the problem behind #{topic}."},
      %{title: "Solution", prompt: "Show the practical solution."},
      %{title: "Next step", prompt: "Give viewers one action to take."}
    ]
  end

  defp sections(points, _topic) do
    points
    |> Enum.with_index(1)
    |> Enum.map(fn {point, index} ->
      %{title: "Section #{index}", prompt: point}
    end)
  end

  defp estimate_minutes(points), do: max(length(points) * 2, 4)

  defp add_edit(suggestions, _type, false, _message), do: suggestions
  defp add_edit(suggestions, type, true, message), do: [%{type: type, message: message} | suggestions]

  defp thumbnail_variants(topic) do
    [
      %{id: "contrast", prompt: "Show the old way versus the new way for #{topic}"},
      %{id: "outcome", prompt: "Show the concrete result viewers want from #{topic}"}
    ]
  end

  defp description(topic, nil, keywords), do: description(topic, "", keywords)

  defp description(topic, summary, keywords) do
    tags =
      keywords
      |> Enum.map(&("#" <> normalize_tag(&1)))
      |> Enum.join(" ")

    [summary, "In this video: #{topic}", tags]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp short_title(nil), do: nil
  defp short_title(title), do: title |> String.trim() |> String.slice(0, 80)

  defp alternate_title(nil), do: nil
  defp alternate_title(title), do: "How to #{title}"

  defp normalize_tag(tag) do
    tag
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_ -]/, "")
    |> String.trim()
  end

  defp fallback(nil, fallback), do: fallback
  defp fallback("", fallback), do: fallback
  defp fallback(value, _fallback), do: value

  defp number(map, key) do
    case value(map, key) do
      value when is_integer(value) -> value
      value when is_float(value) -> value
      _other -> 0
    end
  end

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
