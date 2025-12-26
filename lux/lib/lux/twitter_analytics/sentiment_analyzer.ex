defmodule Lux.TwitterAnalytics.SentimentAnalyzer do
  @moduledoc """
  Simple rule-based sentiment analysis for tweets.

  Analyzes tweet text and returns :positive, :neutral, or :negative sentiment.
  Uses word lists for basic sentiment detection.
  """

  # Positive sentiment words
  @positive_words ~w(
    love like awesome great excellent amazing fantastic wonderful
    happy excited thrilled best brilliant perfect good nice
    beautiful lovely superb outstanding remarkable exceptional
    pleased delighted glad cheerful joyful blessed grateful
    awesome incredible magnificent fabulous terrific
  )

  # Negative sentiment words
  @negative_words ~w(
    hate dislike terrible awful horrible bad worst poor
    sad angry frustrated annoyed upset disappointed unhappy
    pathetic useless broken fail failed failing disaster
    sucks terrible disgusting horrible annoying irritating
    worst pathetic dreadful abysmal atrocious appalling
  )

  # Negation words that flip sentiment
  @negation_words ~w(not no never don't doesn't didn't won't wouldn't can't cannot)

  @doc """
  Analyze the sentiment of text.

  Returns :positive, :neutral, or :negative.

  ## Examples

      iex> SentimentAnalyzer.analyze("I love this!")
      :positive

      iex> SentimentAnalyzer.analyze("This is terrible")
      :negative

      iex> SentimentAnalyzer.analyze("The weather today")
      :neutral
  """
  def analyze(nil), do: :neutral
  def analyze(""), do: :neutral

  def analyze(text) when is_binary(text) do
    # Normalize text: lowercase, remove punctuation, split into words
    words = normalize_text(text)

    # Calculate sentiment scores
    {positive_score, negative_score} = calculate_scores(words)

    # Determine overall sentiment
    cond do
      positive_score > negative_score -> :positive
      negative_score > positive_score -> :negative
      true -> :neutral
    end
  end

  @doc """
  Get detailed sentiment scores.

  Returns a map with positive_score, negative_score, and sentiment.
  """
  def analyze_detailed(text) when is_binary(text) do
    words = normalize_text(text)
    {positive_score, negative_score} = calculate_scores(words)

    sentiment =
      cond do
        positive_score > negative_score -> :positive
        negative_score > positive_score -> :negative
        true -> :neutral
      end

    %{
      sentiment: sentiment,
      positive_score: positive_score,
      negative_score: negative_score,
      total_words: length(words)
    }
  end

  ## Private Functions

  defp normalize_text(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, " ")
    |> String.split()
    |> Enum.reject(&(&1 == ""))
  end

  defp calculate_scores(words) do
    words
    |> Enum.with_index()
    |> Enum.reduce({0, 0}, fn {word, index}, {pos, neg} ->
      is_negated = is_word_negated?(words, index)

      cond do
        word in @positive_words ->
          if is_negated do
            {pos, neg + 1}
          else
            {pos + 1, neg}
          end

        word in @negative_words ->
          if is_negated do
            {pos + 1, neg}
          else
            {pos, neg + 1}
          end

        true ->
          {pos, neg}
      end
    end)
  end

  defp is_word_negated?(words, index) when index > 0 do
    # Check if one of the previous 1-2 words is a negation
    previous_words =
      words
      |> Enum.slice(max(0, index - 2)..(index - 1))

    Enum.any?(previous_words, &(&1 in @negation_words))
  end

  defp is_word_negated?(_words, _index), do: false
end
