defmodule Lux.Prisms.YouTube.Community.SpamDetector do
  @moduledoc """
  Spam detection and moderation for YouTube comments.
  """

  @spam_patterns [
    {~r/sub4sub|sub 4 sub/i, 40},
    {~r/check (out )?my channel/i, 35},
    {~r/free \w+ at \w+\.\w+/i, 40},
    {~r/click (the )?link/i, 30},
    {~r/bit\.ly|tinyurl|t\.co/i, 25},
    {~r/([\x{1F600}-\x{1F64F}].*){5,}/u, 15},
    {~r/(.)\1{4,}/, 20},
    {~r/https?:\/\/\S+/i, 10},
    {~r/[A-Z\s]{20,}/, 15}
  ]

  @doc "Detect spam in a comment. Returns score and matched patterns."
  def detect(text) when is_binary(text) do
    matches = @spam_patterns
    |> Enum.filter(fn {pattern, _} -> Regex.match?(pattern, text) end)
    |> Enum.map(fn {pattern, score} -> %{pattern: Regex.source(pattern), score: score} end)

    total_score = Enum.sum(Enum.map(matches, & &1.score))

    severity = cond do
      total_score >= 60 -> :critical
      total_score >= 40 -> :high
      total_score >= 20 -> :medium
      total_score > 0 -> :low
      true -> :none
    end

    %{
      is_spam: total_score >= 30,
      score: total_score,
      severity: severity,
      matches: matches,
      recommended_action: recommended_action(severity)
    }
  end

  @doc "Batch detect spam."
  def batch_detect(texts) when is_list(texts) do
    results = Enum.map(texts, fn t ->
      text = if is_binary(t), do: t, else: t[:text] || ""
      {text, detect(text)}
    end)

    spam_count = Enum.count(results, fn {_, r} -> r.is_spam end)

    %{
      results: results,
      total: length(results),
      spam_count: spam_count,
      spam_rate: if(length(results) > 0, do: Float.round(spam_count / length(results) * 100, 1), else: 0.0)
    }
  end

  defp recommended_action(:critical), do: :ban_and_delete
  defp recommended_action(:high), do: :delete
  defp recommended_action(:medium), do: :hold_for_review
  defp recommended_action(:low), do: :flag
  defp recommended_action(:none), do: :allow
end
