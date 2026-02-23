defmodule Lux.Prisms.YouTube.GenerateVideoScript do
  @moduledoc """
  A prism for generating structured YouTube video scripts.

  Produces a complete script outline with a hook, content sections,
  and a call-to-action tailored to the video style and duration.
  Supports multiple languages and channel niches. Also generates
  a thumbnail text suggestion for visual consistency.

  ## Examples

      iex> GenerateVideoScript.handler(%{
      ...>   "topic" => "Elixir concurrency",
      ...>   "target_duration_minutes" => 15,
      ...>   "style" => "tutorial",
      ...>   "language" => "en",
      ...>   "channel_niche" => "programming"
      ...> }, %{})
      {:ok, %{
        hook: "By the end of this video, you'll know exactly how to Elixir concurrency...",
        sections: [...],
        call_to_action: "That's it! ...",
        estimated_word_count: 2250,
        thumbnail_text_suggestion: "ELIXIR CONCURRENCY",
        language: "en",
        style: "tutorial"
      }}
  """

  use Lux.Prism,
    name: "Generate YouTube Video Script",
    description: "Generates a structured video script with hook, sections, CTA, and thumbnail suggestion",
    input_schema: %{
      type: :object,
      properties: %{
        topic: %{
          type: :string,
          description: "The main topic or title of the video"
        },
        target_duration_minutes: %{
          type: :integer,
          description: "Target video length in minutes (default: 10)"
        },
        style: %{
          type: :string,
          description: "Script style: 'educational', 'entertainment', 'tutorial', or 'vlog'"
        },
        language: %{
          type: :string,
          description: "BCP-47 language code for the script (e.g., 'en', 'es', 'fr')"
        },
        channel_niche: %{
          type: :string,
          description: "The channel niche for contextual section generation"
        }
      },
      required: ["topic"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        hook: %{type: :string, description: "Opening hook to capture viewer attention"},
        sections: %{
          type: :array,
          description: "Ordered list of script sections",
          items: %{
            type: :object,
            properties: %{
              title: %{type: :string},
              description: %{type: :string},
              estimated_words: %{type: :integer}
            }
          }
        },
        call_to_action: %{type: :string, description: "Closing call-to-action for the video"},
        estimated_word_count: %{type: :integer, description: "Total estimated word count"},
        thumbnail_text_suggestion: %{type: :string, description: "Short text for thumbnail overlay"},
        language: %{type: :string},
        style: %{type: :string}
      },
      required: ["hook", "sections", "call_to_action", "estimated_word_count"]
    }

  require Logger

  @words_per_minute 150

  @doc """
  Generates a structured video script based on the provided parameters.
  """
  @impl true
  def handler(params, agent) do
    topic = params["topic"] || params[:topic]
    duration = params["target_duration_minutes"] || params[:target_duration_minutes] || 10
    style = params["style"] || params[:style] || "educational"
    language = params["language"] || params[:language] || "en"
    niche = params["channel_niche"] || params[:channel_niche] || "general"

    agent_name = get_in(agent, [:agent, :name]) || get_in(agent, ["agent", "name"]) || "Unknown"
    Logger.info("Agent #{agent_name} generating #{style} script for topic: #{topic}")

    target_words = duration * @words_per_minute
    hook = generate_hook(topic, style)
    sections = generate_sections(topic, style, duration, niche)
    cta = generate_cta(style)
    thumbnail_text = generate_thumbnail_text(topic)

    section_words = div(target_words - 100, max(length(sections), 1))

    {:ok, %{
      hook: hook,
      sections: Enum.map(sections, fn s -> Map.put(s, :estimated_words, section_words) end),
      call_to_action: cta,
      estimated_word_count: target_words,
      thumbnail_text_suggestion: thumbnail_text,
      language: language,
      style: style
    }}
  end

  defp generate_hook(topic, "educational") do
    "Did you know that #{topic} could transform the way you think about this subject? " <>
      "In the next few minutes, you'll discover everything you need to know."
  end

  defp generate_hook(topic, "tutorial") do
    "By the end of this video, you'll know exactly how to #{topic}. Let's dive straight in."
  end

  defp generate_hook(topic, "vlog") do
    "Hey everyone! Today we're doing something a little different — we're exploring #{topic} " <>
      "and I can't wait to share this journey with you."
  end

  defp generate_hook(topic, _style) do
    "Welcome back! Today we're talking about #{topic} — and trust me, you don't want to miss this."
  end

  defp generate_sections(topic, "tutorial", duration, _niche) do
    base = [
      %{title: "Prerequisites", description: "What you'll need before starting"},
      %{title: "Step-by-Step Guide", description: "Core walkthrough of #{topic}"},
      %{title: "Common Mistakes", description: "What to avoid when doing #{topic}"},
      %{title: "Pro Tips", description: "Advanced techniques for #{topic}"}
    ]

    maybe_append_faq(base, topic, duration)
  end

  defp generate_sections(topic, "educational", duration, _niche) do
    base = [
      %{title: "Introduction to #{topic}", description: "Core concepts explained simply"},
      %{title: "Why #{topic} Matters", description: "Real-world applications and impact"},
      %{title: "Deep Dive", description: "Advanced aspects of #{topic}"},
      %{title: "Practical Examples", description: "Concrete use cases and demonstrations"}
    ]

    maybe_append_faq(base, topic, duration)
  end

  defp generate_sections(topic, "vlog", duration, _niche) do
    base = [
      %{title: "Setting the Scene", description: "Where we are and what we're doing"},
      %{title: "Main Adventure", description: "Core experience related to #{topic}"},
      %{title: "Reflections", description: "What I learned and felt about #{topic}"}
    ]

    maybe_append_faq(base, topic, duration)
  end

  defp generate_sections(topic, _style, duration, _niche) do
    base = [
      %{title: "Introduction", description: "Setting the scene for #{topic}"},
      %{title: "Main Content", description: "Core discussion about #{topic}"},
      %{title: "Key Takeaways", description: "Summary of the most important points"}
    ]

    maybe_append_faq(base, topic, duration)
  end

  defp maybe_append_faq(sections, topic, duration) when duration > 15 do
    sections ++ [%{title: "Q&A / FAQs", description: "Answering common questions about #{topic}"}]
  end

  defp maybe_append_faq(sections, _topic, _duration), do: sections

  defp generate_cta("educational") do
    "If you found this helpful, smash that like button and subscribe for more content like this. " <>
      "Drop your questions in the comments below!"
  end

  defp generate_cta("tutorial") do
    "That's it! You now know how to do it. Like and subscribe if this helped you, " <>
      "and let me know what you built in the comments!"
  end

  defp generate_cta("vlog") do
    "Thanks for coming along on this journey with me! Hit like if you enjoyed it, " <>
      "subscribe for more adventures, and I'll see you in the next one!"
  end

  defp generate_cta(_style) do
    "Thanks for watching! Like, comment, and subscribe to support the channel. See you in the next one!"
  end

  defp generate_thumbnail_text(topic) do
    words = String.split(topic)

    if length(words) <= 3 do
      String.upcase(topic)
    else
      words |> Enum.take(3) |> Enum.join(" ") |> String.upcase()
    end
  end
end
