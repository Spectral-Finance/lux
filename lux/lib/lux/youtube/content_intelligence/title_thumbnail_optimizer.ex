defmodule Lux.YouTube.ContentIntelligence.TitleThumbnailOptimizer do
  @moduledoc """
  Analyzes and scores video titles and thumbnail specifications for maximum Click-Through Rate (CTR).
  Generates high-performing title variants and audits visual contrast and text density.
  """

  @power_words ~w(secret ultimate insane dangerous truth breakthrough reveal fatal warned never stop instantly best top guide blueprint)
  @curiosity_triggers ~w(why what how this you won't believe actually happened)

  @type title_analysis :: %{
          original_title: String.t(),
          character_count: non_neg_integer(),
          word_count: non_neg_integer(),
          ctr_potential_score: float(),
          has_power_words: boolean(),
          power_words_found: list(String.t()),
          has_numbers: boolean(),
          has_brackets: boolean(),
          mobile_truncation_risk: boolean(),
          strengths: list(String.t()),
          weaknesses: list(String.t())
        }

  @type thumbnail_spec :: %{
          estimated_contrast_ratio: float(),
          text_word_count: non_neg_integer(),
          has_human_face: boolean(),
          mobile_readability_score: float(),
          visual_clutter_verdict: :clean | :balanced | :cluttered
        }

  @doc """
  Evaluates a candidate video title and assigns a CTR potential score with actionable suggestions.
  """
  @spec analyze_title(String.t()) :: title_analysis()
  def analyze_title(title) when is_binary(title) do
    cleaned = String.trim(title)
    char_len = String.length(cleaned)
    words = String.split(cleaned, ~r/[^\w\d]+/, trim: true)
    word_len = length(words)

    downcased_words = Enum.map(words, &String.downcase/1)
    found_power = Enum.filter(downcased_words, &(&1 in @power_words))
    found_curiosity = Enum.filter(downcased_words, &(&1 in @curiosity_triggers))

    has_numbers = Regex.match?(~r/\d+/, cleaned)
    has_brackets = Regex.match?(~r/[\[\(\{].*[\]\)\}]/, cleaned)
    truncation_risk = char_len > 65

    # Calculate CTR potential score 0 - 100
    base_score = 50.0

    score =
      base_score
      |> Kernel.+(if length(found_power) > 0, do: 15.0, else: -5.0)
      |> Kernel.+(if length(found_curiosity) > 0, do: 10.0, else: 0.0)
      |> Kernel.+(if has_numbers, do: 10.0, else: 0.0)
      |> Kernel.+(if has_brackets, do: 8.0, else: 0.0)
      |> Kernel.+(if char_len in 45..62, do: 12.0, else: if(truncation_risk, do: -15.0, else: 0.0))
      |> min(100.0)
      |> max(10.0)
      |> Float.round(1)

    strengths = []
    strengths = if length(found_power) > 0, do: ["Contains compelling power words: #{Enum.join(found_power, ", ")}" | strengths], else: strengths
    strengths = if has_numbers, do: ["Incorporates specific numbers which boosts CTR by ~18%" | strengths], else: strengths
    strengths = if char_len in 45..62, do: ["Optimal length for both desktop and mobile viewports" | strengths], else: strengths

    weaknesses = []
    weaknesses = if truncation_risk, do: ["Exceeds 65 characters; title will be truncated on mobile devices" | weaknesses], else: weaknesses
    weaknesses = if length(found_power) == 0, do: ["Lacks strong psychological hook or power words" | weaknesses], else: weaknesses
    weaknesses = if char_len < 30, do: ["Title may be too short to convey value proposition" | weaknesses], else: weaknesses

    %{
      original_title: cleaned,
      character_count: char_len,
      word_count: word_len,
      ctr_potential_score: score,
      has_power_words: length(found_power) > 0,
      power_words_found: found_power,
      has_numbers: has_numbers,
      has_brackets: has_brackets,
      mobile_truncation_risk: truncation_risk,
      strengths: Enum.reverse(strengths),
      weaknesses: Enum.reverse(weaknesses)
    }
  end

  @doc """
  Generates 4 high-CTR variants for A/B testing across different psychological angles.
  """
  @spec generate_variants(String.t()) :: list(%{variant: String.t(), angle: String.t(), projected_ctr_lift: String.t()})
  def generate_variants(base_topic) when is_binary(base_topic) do
    cleaned = String.trim(base_topic)

    [
      %{
        variant: "The Ultimate #{cleaned} Blueprint [2026 Guide]",
        angle: "High Authority / Comprehensive",
        projected_ctr_lift: "+22% CTR"
      },
      %{
        variant: "Why Most Developers Fail at #{cleaned} (And How to Fix It)",
        angle: "Curiosity Gap / Fear of Missing Out",
        projected_ctr_lift: "+35% CTR"
      },
      %{
        variant: "I Built a Production #{cleaned} in 24 Hours",
        angle: "Personal Story / Extreme Constraint",
        projected_ctr_lift: "+28% CTR"
      },
      %{
        variant: "Stop Doing #{cleaned} Like This! (Fatal Mistakes)",
        angle: "Negative Warning / Pattern Interrupt",
        projected_ctr_lift: "+40% CTR"
      }
    ]
  end

  @doc """
  Audits thumbnail parameters for visual impact and mobile legibility.
  """
  @spec audit_thumbnail(map()) :: thumbnail_spec()
  def audit_thumbnail(params) when is_map(params) do
    words = Map.get(params, :overlay_text_word_count, Map.get(params, "overlay_text_word_count", 3))
    has_face = Map.get(params, :has_human_face, Map.get(params, "has_human_face", true))
    contrast_ratio = Map.get(params, :contrast_ratio, Map.get(params, "contrast_ratio", 4.8))

    readability_score =
      cond do
        words <= 4 and contrast_ratio >= 4.5 -> 95.0
        words <= 6 and contrast_ratio >= 3.0 -> 78.0
        true -> 50.0
      end

    clutter =
      cond do
        words <= 3 -> :clean
        words <= 5 -> :balanced
        true -> :cluttered
      end

    %{
      estimated_contrast_ratio: contrast_ratio,
      text_word_count: words,
      has_human_face: has_face,
      mobile_readability_score: readability_score,
      visual_clutter_verdict: clutter
    }
  end
end
