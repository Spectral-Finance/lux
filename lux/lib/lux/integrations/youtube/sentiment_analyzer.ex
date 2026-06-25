defmodule Lux.Integrations.Youtube.SentimentAnalyzer do
  @moduledoc """
  Sentiment analysis for YouTube comments.
  
  Uses keyword-based scoring for positive/negative/neutral classification.
  """

  @positive_words ~w[great awesome excellent love like good best thank thanks appreciate helpful useful amazing wonderful fantastic brilliant]
  @negative_words ~w[bad hate terrible awful worst terrible disappointment scam fraud broken useless annoying slow]
  @neutral_words ~w[question inquiry ask how what when where who why]

  @doc """
  Analyzes the sentiment of a text.
  """
  @spec analyze(String.t()) :: %{score: float(), label: String.t()}
  def analyze(text) when is_binary(text) do
    words = String.downcase(text) |> String.split(~r/[\s,.;:!?\"]/)
    
    pos_count = Enum.count(words, &(&1 in @positive_words))
    neg_count = Enum.count(words, &(&1 in @negative_words))
    
    total = pos_count + neg_count
    
    score = if total == 0 do
      0.0
    else
      (pos_count - neg_count) / total
    end
    
    label = case score do
      s when s > 0.3 -> "positive"
      s when s < -0.3 -> "negative"
      _ -> "neutral"
    end
    
    %{score: score, label: label}
  end

  def analyze(_), do: %{score: 0.0, label: "neutral"}
end
