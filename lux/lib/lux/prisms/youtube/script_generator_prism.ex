defmodule Lux.Prisms.Youtube.ScriptGeneratorPrism do
  @moduledoc """
  A prism that generates optimized YouTube video scripts using LLM capabilities.

  Creates structured video scripts with hooks, main content, CTAs, and
  engagement optimization based on video topic, target audience, and
  performance data.

  ## Examples

      iex> Lux.Prisms.Youtube.ScriptGeneratorPrism.run(%{
      ...>   topic: "Building a DeFi Dashboard with Elixir",
      ...>   target_audience: "Web3 developers",
      ...>   duration_minutes: 10,
      ...>   tone: "educational",
      ...>   include_hooks: true,
      ...>   include_cta: true
      ...> })
      {:ok, %{script: "...", sections: [...], estimated_duration: 600}}
  """

  use Lux.Prism,
    name: "YouTube Script Generator",
    description: "Generates optimized YouTube video scripts with hooks, content sections, and CTAs",
    input_schema: %{
      type: :object,
      properties: %{
        topic: %{
          type: :string,
          description: "Main topic or title of the video"
        },
        target_audience: %{
          type: :string,
          description: "Target audience description"
        },
        duration_minutes: %{
          type: :integer,
          description: "Target video duration in minutes",
          default: 10
        },
        tone: %{
          type: :string,
          description: "Script tone/style",
          enum: ["educational", "entertaining", "professional", "casual", "inspirational"],
          default: "educational"
        },
        key_points: %{
          type: :array,
          items: %{type: :string},
          description: "Key points to cover in the video"
        },
        include_hooks: %{
          type: :boolean,
          description: "Include attention-grabbing hooks",
          default: true
        },
        include_cta: %{
          type: :boolean,
          description: "Include call-to-action sections",
          default: true
        },
        language: %{
          type: :string,
          description: "Output language",
          default: "en"
        }
      },
      required: ["topic"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        script: %{type: :string},
        sections: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              start_time: %{type: :string},
              duration_seconds: %{type: :integer},
              content: %{type: :string},
              visual_notes: %{type: :string}
            }
          }
        },
        estimated_duration: %{type: :integer},
        word_count: %{type: :integer},
        hooks: %{type: :array},
        suggested_ctas: %{type: :array}
      }
    }

  @words_per_minute 150

  @doc """
  Generates a YouTube video script based on the provided parameters.
  """
  def run(params) do
    topic = Map.get(params, :topic, params["topic"])
    target_audience = Map.get(params, :target_audience, params["target_audience"] || "general audience")
    duration_minutes = Map.get(params, :duration_minutes, params["duration_minutes"] || 10)
    tone = Map.get(params, :tone, params["tone"] || "educational")
    key_points = Map.get(params, :key_points, params["key_points"] || [])
    include_hooks = Map.get(params, :include_hooks, params["include_hooks"] || true)
    include_cta = Map.get(params, :include_cta, params["include_cta"] || true)
    language = Map.get(params, :language, params["language"] || "en")

    target_words = duration_minutes * @words_per_minute

    script = generate_script(%{
      topic: topic,
      target_audience: target_audience,
      duration_minutes: duration_minutes,
      tone: tone,
      key_points: key_points,
      include_hooks: include_hooks,
      include_cta: include_cta,
      target_words: target_words,
      language: language
    })

    {:ok, script}
  end

  defp generate_script(params) do
    %{
      topic: topic,
      target_audience: audience,
      duration_minutes: duration,
      tone: tone,
      key_points: key_points,
      include_hooks: include_hooks,
      include_cta: include_cta,
      target_words: target_words,
      language: language
    } = params

    # Calculate section durations
    hook_duration = if include_hooks, do: max(1, div(duration, 8)), else: 0
    cta_duration = if include_cta, do: max(1, div(duration, 10)), else: 0
    content_duration = duration - hook_duration - cta_duration

    # Generate sections
    sections = build_sections(%{
      hook_duration: hook_duration,
      content_duration: content_duration,
      cta_duration: cta_duration,
      topic: topic,
      audience: audience,
      tone: tone,
      key_points: key_points
    })

    # Generate hooks
    hooks = if include_hooks do
      generate_hooks(topic, tone, audience)
    else
      []
    end

    # Generate CTAs
    suggested_ctas = if include_cta do
      generate_ctas(topic, audience)
    else
      []
    end

    # Build full script text
    script_text = build_script_text(sections, hooks, suggested_ctas)

    %{
      script: script_text,
      sections: sections,
      estimated_duration: duration * 60,
      word_count: target_words,
      hooks: hooks,
      suggested_ctas: suggested_ctas
    }
  end

  defp build_sections(params) do
    %{
      hook_duration: hook_dur,
      content_duration: content_dur,
      cta_duration: cta_dur,
      topic: topic,
      audience: audience,
      tone: tone,
      key_points: key_points
    } = params

    sections = []

    # Hook section
    sections = if hook_dur > 0 do
      [%{
        name: "Hook / Opening",
        start_time: "0:00",
        duration_seconds: hook_dur * 60,
        content: "Open with a compelling question or surprising fact about #{topic}.",
        visual_notes: "Full-screen title card with dynamic text animation"
      } | sections]
    else
      sections
    end

    # Introduction section
    sections = [%{
      name: "Introduction",
      start_time: format_time(hook_dur * 60),
      duration_seconds: max(30, div(content_dur, 4) * 60),
      content: "Introduce #{topic} and explain why it matters to #{audience}. Set expectations for what viewers will learn.",
      visual_notes: "Speaker on camera with topic title overlay"
    } | sections]

    # Content sections based on key points
    content_sections = if length(key_points) > 0 do
      point_duration = div(content_dur, max(1, length(key_points)))
      Enum.with_index(key_points, 1)
      |> Enum.map(fn {point, idx} ->
        start_offset = hook_dur + div(content_dur, 4) + (point_duration * (idx - 1))
        %{
          name: "Section #{idx}: #{point}",
          start_time: format_time(start_offset * 60),
          duration_seconds: point_duration * 60,
          content: "Deep dive into: #{point}. Provide examples and practical demonstrations.",
          visual_notes: "Screen recording or diagram with voiceover"
        }
      end)
    else
      [%{
        name: "Main Content",
        start_time: format_time((hook_dur + div(content_dur, 4)) * 60),
        duration_seconds: div(content_dur, 2) * 60,
        content: "Present the core content about #{topic} with examples and demonstrations.",
        visual_notes: "Mixed: speaker + screen share + B-roll"
      }]
    end

    sections = content_sections ++ sections

    # Summary section
    sections = [%{
      name: "Summary",
      start_time: format_time((hook_dur + content_dur - max(1, div(content_dur, 8))) * 60),
      duration_seconds: max(30, div(content_dur, 8) * 60),
      content: "Recap key takeaways from the video. Reinforce the main message.",
      visual_notes: "Bullet point summary with checkmarks"
    } | sections]

    # CTA section
    sections = if cta_dur > 0 do
      [%{
        name: "Call to Action",
        start_time: format_time((hook_dur + content_dur) * 60),
        duration_seconds: cta_dur * 60,
        content: "Encourage viewers to like, subscribe, and comment. Direct to related content.",
        visual_notes: "End screen with subscribe button and video recommendations"
      } | sections]
    else
      sections
    end

    Enum.reverse(sections)
  end

  defp generate_hooks(topic, tone, audience) do
    [
      "\"Did you know that #{topic} can transform how #{audience} work? Let me show you how.\"",
      "\"I spent 100 hours mastering #{topic} so you don't have to. Here's everything I learned.\"",
      "\"Most #{audience} are making this critical mistake with #{topic}. Let me fix that.\"",
      "\"What if I told you #{topic} is easier than you think? In the next #{div(10, 1)} minutes, I'll prove it.\""
    ]
  end

  defp generate_ctas(topic, audience) do
    [
      "\"If this helped you understand #{topic}, hit that subscribe button for more #{audience} content.\"",
      "\"Drop a comment below with your biggest challenge around #{topic} — I read every single one.\"",
      "\"Want the full code? Link in the description. Don't forget to star the repo!\""
    ]
  end

  defp build_script_text(sections, hooks, ctas) do
    lines = []

    lines = if length(hooks) > 0 do
      ["## HOOKS (Choose one)\n"] ++ Enum.map(hooks, &"• #{&1}\n") ++ ["\n"] ++ lines
    else
      lines
    end

    lines = Enum.reduce(sections, lines, fn section, acc ->
      acc ++ [
        "\n## #{section.name}",
        "⏱️ #{section.start_time} (#{section.duration_seconds}s)",
        "",
        section.content,
        "",
        "🎬 Visual: #{section.visual_notes}",
        ""
      ]
    end)

    lines = if length(ctas) > 0 do
      lines ++ ["\n## SUGGESTED CTAs\n"] ++ Enum.map(ctas, &"• #{&1}\n")
    else
      lines
    end

    Enum.join(lines, "\n")
  end

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end
end
