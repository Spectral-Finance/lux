defmodule Lux.Integrations.Youtube.SpamDetector do
  @moduledoc """
  Spam detection for YouTube comments.
  
  Uses heuristic-based detection for common spam patterns.
  """

  @spam_patterns ~r/(click here|buy now|free money|make money|subscribe now|follow me|check out|visit my|discount code|promo code)/i
  @spam_indicators ~w[http://www. https://www. www. telegram discord whatsapp tiktok instagram youtube twitter facebook]

  @doc """
  Detects spam in a comment.
  Returns a score between 0.0 (not spam) and 1.0 (definite spam).
  """
  @spec detect(String.t(), map()) :: float()
  def detect(text, metadata \\ %{}) when is_binary(text) do
    score = 0.0
    
    # Check for spam patterns
    pattern_score = if Regex.match?(@spam_patterns, text), do: 0.3, else: 0.0
    
    # Check for indicators
    words = String.downcase(text) |> String.split(~r/[\s]/)
    indicator_count = Enum.count(words, &(&1 in @spam_indicators))
    indicator_score = min(indicator_count * 0.1, 0.4)
    
    # Check for excessive links
    link_count = String.split(text, ~r/https?:\/\//) |> length() - 1
    link_score = min(link_count * 0.2, 0.5)
    
    # Check for excessive capitalization
    upper_count = String.length(String.upcase(text))
    upper_score = if upper_count > String.length(text) * 0.5, do: 0.2, else: 0.0
    
    score = pattern_score + indicator_score + link_score + upper_score
    
    min(score, 1.0)
  end

  def detect(_, _), do: 0.0
end
