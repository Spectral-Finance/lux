defmodule Lux.YouTube.ContentIntelligence.TitleThumbnailOptimizer do
  @moduledoc """
  Title and thumbnail optimization for YouTube content intelligence.

  Provides title CTR psychological scoring, mobile truncation defense,
  A/B angle variant generation, and thumbnail contrast/clutter audits.
  """

  @doc """
  Optimizes a video title for CTR and clarity.
  """
  def optimize_title(input) when is_map(input) do
    with {:ok, validated} <- validate_input(input) do
      title = validated.title
      ctr_score = calculate_ctr_score(title)
      mobile_warning = check_mobile_truncation(title)
      variants = if validated.include_ab_variants, do: generate_ab_variants(title), else: []

      {:ok, %{
        ctr_score: ctr_score,
        mobile_truncation_warning: mobile_warning,
        ab_test_variants: variants,
        character_count: String.length(title),
        optimized_title: suggest_optimized_title(title, ctr_score)
      }}
    end
  end

  def optimize_title(_input), do: {:error, :invalid_input}

  @doc """
  Calculates CTR psychological score for a title (0-100).
  """
  def ctr_score(title) when is_binary(title) do
    calculate_ctr_score(title)
  end

  def ctr_score(_), do: {:error, :invalid_input}

  @doc """
  Checks if a title will be truncated on mobile devices.
  """
  def mobile_truncation?(title) when is_binary(title) do
    String.length(title) > 60
  end

  def mobile_truncation?(_), do: {:error, :invalid_input}

  @doc """
  Generates A/B test title variants.
  """
  def ab_test_variants(title) when is_binary(title) do
    generate_ab_variants(title)
  end

  def ab_test_variants(_), do: {:error, :invalid_input}

  @doc """
  Audits thumbnail contrast and clutter.
  """
  def audit_thumbnail(thumbnail_description) when is_binary(thumbnail_description) do
    contrast_score = calculate_contrast_score(thumbnail_description)
    clutter_score = calculate_clutter_score(thumbnail_description)

    {:ok, %{
      contrast_score: contrast_score,
      clutter_score: clutter_score,
      recommendation: (if contrast_score > 70 and clutter_score < 50, do: "Good", else: "Needs improvement")
    }}
  end

  def audit_thumbnail(_), do: {:error, :invalid_input}

  # Private helpers

  defp validate_input(input) do
    required = [:title]

    missing = Enum.filter(required, fn key -> not Map.has_key?(input, key) end)

    if missing != [] do
      {:error, {:missing_fields, missing}}
    else
      if is_binary(input.title) do
        {:ok, Map.put(input, :include_ab_variants, Map.get(input, :include_ab_variants, true))}
      else
        {:error, {:invalid_value, :title}}
      end
    end
  end

  defp calculate_ctr_score(title) do
    power_words = ["secret", "revealed", "shocking", "ultimate", "complete", "essential"]

    power_word_bonus =
      Enum.reduce(power_words, 0, fn word, acc ->
        if String.contains?(title, word), do: acc + 10.0, else: acc
      end)

    number_bonus = if Regex.match?(~r/\d/, title), do: 15.0, else: 0.0
    question_bonus = if String.contains?(title, "?"), do: 5.0, else: 0.0

    len = String.length(title)
    length_penalty =
      cond do
        len > 100 -> -20.0
        len > 60 -> -10.0
        true -> 0.0
      end

    short_penalty = if len < 10, do: -15.0, else: 0.0

    score = 50.0 + power_word_bonus + number_bonus + question_bonus + length_penalty + short_penalty

    round(clamp(score, 0.0, 100.0) * 100) / 100
  end

  defp check_mobile_truncation(title) do
    if String.length(title) > 60 do
      "Title exceeds 60 characters and may be truncated on mobile devices"
    else
      nil
    end
  end

  defp generate_ab_variants(title) do
    [
      %{"variant" => "A", "title" => title, "angle" => "original"},
      %{"variant" => "B", "title" => "How to #{title}", "angle" => "instructional"},
      %{"variant" => "C", "title" => "#{title} (Complete Guide)", "angle" => "comprehensive"},
      %{"variant" => "D", "title" => title <> " - You Won't Believe", "angle" => "curiosity"}
    ]
  end

  defp suggest_optimized_title(title, ctr_score) do
    if ctr_score < 70 do
      "How to #{title} - Complete Guide"
    else
      title
    end
  end

  defp calculate_contrast_score(description) do
    contrast_bonus = if String.contains?(description, "high contrast") or String.contains?(description, "bright"), do: 25.0, else: 0.0
    dark_penalty = if String.contains?(description, "dark") or String.contains?(description, "shadow"), do: -10.0, else: 0.0

    score = 50.0 + contrast_bonus + dark_penalty

    round(clamp(score, 0.0, 100.0))
  end

  defp calculate_clutter_score(description) do
    word_count = String.split(description) |> length()

    clutter_bonus =
      cond do
        word_count > 20 -> 30.0
        word_count > 10 -> 15.0
        true -> 0.0
      end

    score = 30.0 + clutter_bonus

    round(clamp(score, 0.0, 100.0))
  end

  defp clamp(value, min_val, max_val) do
    min(max(value, min_val), max_val)
  end
end