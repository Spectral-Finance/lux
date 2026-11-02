defmodule Lux.YouTube.ContentCreation.VisualOptimizer do
  @moduledoc """
  Generates visual specifications for high-converting thumbnails,
  optimal end screen element layouts, and interactive info card placements.
  """

  @type thumbnail_spec :: %{
          primary_palette: list(String.t()),
          focal_subject: String.t(),
          badge_text: String.t(),
          composition_rule: String.t(),
          font_recommendation: String.t(),
          contrast_ratio_target: float(),
          prompt_for_ai_generator: String.t()
        }

  @type end_screen_element :: %{
          type: :best_for_viewer | :recent_upload | :playlist | :subscribe_button,
          position: String.t(),
          start_offset_seconds: non_neg_integer(),
          end_offset_seconds: non_neg_integer()
        }

  @type card_element :: %{
          timestamp: String.t(),
          teaser_text: String.t(),
          target_url_or_playlist: String.t()
        }

  @doc """
  Builds thumbnail artistic brief and AI generation prompts tailored to the video topic.
  """
  @spec generate_thumbnail_spec(String.t(), keyword() | map()) :: thumbnail_spec()
  def generate_thumbnail_spec(topic, opts \\ %{}) do
    style =
      if is_map(opts),
        do: Map.get(opts, :style, Map.get(opts, "style", "modern_tech")),
        else: Keyword.get(opts, :style, "modern_tech")

    badge =
      if is_map(opts),
        do: Map.get(opts, :badge_text, Map.get(opts, "badge_text", "DON'T MISS THIS")),
        else: Keyword.get(opts, :badge_text, "DON'T MISS THIS")

    prompt =
      "High-contrast YouTube thumbnail background, #{style} aesthetic, vibrant neon blue and orange glow, featuring a clean diagram representing #{topic}, dramatic lighting, ultra-sharp 8k resolution, rule of thirds composition with negative space on right for text overlay."

    %{
      primary_palette: ["#0A0F1D", "#00FFA3", "#FF007A", "#FFFFFF"],
      focal_subject: "Developer or expressive technical face on right third, holographic system node on left third",
      badge_text: badge,
      composition_rule: "Rule of thirds: Subject right, maximum 3-word bold badge upper-left with heavy drop shadow",
      font_recommendation: "Montserrat Black or Bebas Neue with yellow/white fill and black stroke",
      contrast_ratio_target: 6.5,
      prompt_for_ai_generator: prompt
    }
  end

  @doc """
  Generates an optimized YouTube End Screen layout configuration for the final 20 seconds.
  """
  @spec build_end_screen_layout(non_neg_integer()) :: list(end_screen_element())
  def build_end_screen_layout(video_duration_seconds) do
    start_time = max(video_duration_seconds - 20, 0)
    end_time = video_duration_seconds

    [
      %{
        type: :playlist,
        position: "Top Left (X: 10%, Y: 15%, Width: 33%, Height: 33%)",
        start_offset_seconds: start_time,
        end_offset_seconds: end_time
      },
      %{
        type: :best_for_viewer,
        position: "Top Right (X: 57%, Y: 15%, Width: 33%, Height: 33%)",
        start_offset_seconds: start_time,
        end_offset_seconds: end_time
      },
      %{
        type: :subscribe_button,
        position: "Center Bottom (X: 43%, Y: 60%, Width: 14%, Height: 25%)",
        start_offset_seconds: start_time + 2,
        end_offset_seconds: end_time
      }
    ]
  end

  @doc """
  Generates info cards strategically placed before mid-video drop-off points.
  """
  @spec plan_info_cards(non_neg_integer(), list(String.t())) :: list(card_element())
  def plan_info_cards(duration_seconds, related_topics) do
    # Strategic placement at 25% and 65% of video duration
    t1 = div(duration_seconds, 4)
    t2 = div(duration_seconds * 13, 20)

    topic1 = Enum.at(related_topics, 0, "Architecture Deep Dive")
    topic2 = Enum.at(related_topics, 1, "Complete Series Playlist")

    [
      %{
        timestamp: format_seconds(t1),
        teaser_text: "Watch next: #{topic1}",
        target_url_or_playlist: "https://youtube.com/playlist?list=lux_#{String.downcase(String.replace(topic1, " ", "_"))}"
      },
      %{
        timestamp: format_seconds(t2),
        teaser_text: "Explore: #{topic2}",
        target_url_or_playlist: "https://youtube.com/playlist?list=lux_series_mastery"
      }
    ]
  end

  defp format_seconds(seconds) do
    mins = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{String.pad_leading(to_string(mins), 2, "0")}:#{String.pad_leading(to_string(secs), 2, "0")}"
  end
end
