defmodule Lux.YouTube.ContentCreation.ScriptGenerator do
  @moduledoc """
  Generates production-grade YouTube video scripts structured for maximum audience retention.
  Includes hooks, chapter pacing, pattern interrupts, and seamless call-to-actions.
  """

  @speaking_rate_wpm 150

  @type script_section :: %{
          name: String.t(),
          timestamp_estimate: String.t(),
          content: String.t(),
          director_notes: String.t(),
          target_duration_seconds: non_neg_integer()
        }

  @type video_script :: %{
          title: String.t(),
          topic: String.t(),
          format: :tutorial | :deep_dive | :case_study | :quick_explainer,
          estimated_duration_minutes: float(),
          total_word_count: non_neg_integer(),
          sections: list(script_section()),
          hook: String.t(),
          cta: String.t()
        }

  @doc """
  Generates a full video script based on a given topic and target parameters.
  """
  @spec generate_script(map() | keyword()) :: video_script()
  def generate_script(params) do
    topic = get_param(params, :topic, "Building Autonomous AI Agents in Elixir")
    format = get_param(params, :format, :tutorial)
    target_minutes = get_param(params, :target_minutes, 10.0)
    channel_name = get_param(params, :channel_name, "Lux Engineering")

    hook_text = "What if you could build self-healing AI agents that coordinate complex workflows in under 100 lines of code? Today, we are breaking down #{topic}."
    intro_text = "In this video, we're not just looking at high-level theory. We will build a complete, production-grade system step-by-step using #{channel_name}'s architecture."
    
    body_chapters = generate_body_chapters(topic, format)
    cta_text = "If you want the complete source code and architectural blueprints, check the GitHub repository linked in the description and hit subscribe for weekly deep dives."
    outro_text = "Thanks for watching! Next up, click the video on screen to see how we scale these agents across distributed clusters."

    sections = [
      %{
        name: "Hook & Stake",
        timestamp_estimate: "00:00",
        content: hook_text,
        director_notes: "High energy, fast-cut B-roll, punch-in on face at key statement.",
        target_duration_seconds: 15
      },
      %{
        name: "Problem & Context",
        timestamp_estimate: "00:15",
        content: intro_text,
        director_notes: "Show architecture diagram overlay on screen with subtle animation.",
        target_duration_seconds: 45
      }
    ] ++ body_chapters ++ [
      %{
        name: "Call to Action",
        timestamp_estimate: format_seconds(round(target_minutes * 60 - 45)),
        content: cta_text,
        director_notes: "Lower third graphic pops showing GitHub URL and subscribe icon.",
        target_duration_seconds: 30
      },
      %{
        name: "Outro & End-Card Bridge",
        timestamp_estimate: format_seconds(round(target_minutes * 60 - 15)),
        content: outro_text,
        director_notes: "Point directly to end screen video container on right quadrant.",
        target_duration_seconds: 15
      }
    ]

    total_words =
      sections
      |> Enum.map(& &1.content)
      |> Enum.join(" ")
      |> String.split(~r/\s+/, trim: true)
      |> length()

    est_duration = Float.round(total_words / @speaking_rate_wpm, 1)

    %{
      title: "Mastering #{topic} [Complete Guide]",
      topic: topic,
      format: format,
      estimated_duration_minutes: est_duration,
      total_word_count: total_words,
      sections: sections,
      hook: hook_text,
      cta: cta_text
    }
  end

  defp generate_body_chapters(topic, :tutorial) do
    [
      %{
        name: "Prerequisites & Core Concepts",
        timestamp_estimate: "01:00",
        content: "Before we dive into the code, let's understand the core building blocks required for #{topic}. We'll examine the state machine and fault-tolerance model.",
        director_notes: "Side-by-side terminal and code editor view.",
        target_duration_seconds: 120
      },
      %{
        name: "Live Implementation",
        timestamp_estimate: "03:00",
        content: "Now let's get our hands dirty. Watch as we construct the core handler module, register callbacks, and wire up asynchronous event listeners.",
        director_notes: "Full screen screen-share with syntax highlighting and highlighted diffs.",
        target_duration_seconds: 240
      },
      %{
        name: "Testing & Validation",
        timestamp_estimate: "07:00",
        content: "Let's run our test suite to verify that edge cases, timeouts, and network disconnects are handled without crashing our supervisor.",
        director_notes: "Terminal output running tests with green assertions.",
        target_duration_seconds: 120
      }
    ]
  end

  defp generate_body_chapters(topic, _other) do
    [
      %{
        name: "Deep Architecture Breakdown",
        timestamp_estimate: "01:00",
        content: "Examining the fundamental engineering trade-offs behind #{topic}. Why traditional paradigms fail under scale.",
        director_notes: "Whiteboard or animated schema diagram.",
        target_duration_seconds: 180
      },
      %{
        name: "Production Case Study",
        timestamp_estimate: "04:00",
        content: "Real-world benchmarks, latency measurements, and memory consumption profiles under heavy production loads.",
        director_notes: "Graphs and telemetry charts displaying benchmarks.",
        target_duration_seconds: 240
      }
    ]
  end

  defp get_param(params, key, default) when is_map(params) do
    Map.get(params, key, Map.get(params, to_string(key), default))
  end

  defp get_param(params, key, default) when is_list(params) do
    Keyword.get(params, key, default)
  end

  defp format_seconds(total_seconds) do
    mins = div(total_seconds, 60)
    secs = rem(total_seconds, 60)
    "#{String.pad_leading(to_string(mins), 2, "0")}:#{String.pad_leading(to_string(secs), 2, "0")}"
  end
end
