defmodule Lux.Prisms.YouTube.Util do
  @moduledoc """
  Shared helpers for the YouTube Community Management prisms (lux issue #70).

  Pure, deterministic text/number utilities: tokenization, stopword sets,
  safe division, number coercion, and simple lexical math used by the
  sentiment, spam-detection, and response-generation prisms. No network
  calls — callers pass in comment payloads fetched via their YouTube client.
  """

  @stopwords MapSet.new([
               "the",
               "a",
               "an",
               "and",
               "or",
               "but",
               "of",
               "to",
               "in",
               "on",
               "for",
               "with",
               "is",
               "are",
               "was",
               "were",
               "be",
               "this",
               "that",
               "it",
               "as",
               "at",
               "by",
               "from",
               "i",
               "you",
               "your",
               "my",
               "me",
               "so",
               "if",
               "do",
               "does",
               "did",
               "not",
               "no",
               "yes",
               "we",
               "us"
             ])

  # A compact, dependency-free positive/negative lexicon. Each entry is a
  # word -> valence in [-1.0, 1.0]. Kept intentionally small and transparent
  # so the sentiment score is explainable and auditable.
  @lexicon %{
    "love" => 1.0,
    "loved" => 1.0,
    "loving" => 1.0,
    "great" => 0.8,
    "awesome" => 1.0,
    "amazing" => 1.0,
    "excellent" => 1.0,
    "perfect" => 1.0,
    "best" => 0.9,
    "good" => 0.6,
    "nice" => 0.6,
    "helpful" => 0.7,
    "thanks" => 0.7,
    "thank" => 0.7,
    "beautiful" => 0.8,
    "brilliant" => 0.9,
    "fantastic" => 1.0,
    "wonderful" => 0.9,
    "incredible" => 1.0,
    "recommend" => 0.7,
    "enjoy" => 0.6,
    "enjoyed" => 0.6,
    "fun" => 0.5,
    "cool" => 0.4,
    "happy" => 0.7,
    "impressive" => 0.8,
    "clear" => 0.4,
    "useful" => 0.6,
    "valuable" => 0.7,
    "well" => 0.4,
    "works" => 0.4,
    "hate" => -1.0,
    "hated" => -1.0,
    "terrible" => -1.0,
    "awful" => -1.0,
    "worst" => -1.0,
    "bad" => -0.6,
    "poor" => -0.6,
    "boring" => -0.6,
    "useless" => -0.8,
    "waste" => -0.8,
    "disappointed" => -0.7,
    "disappointing" => -0.7,
    "stupid" => -0.9,
    "scam" => -1.0,
    "broken" => -0.7,
    "wrong" => -0.5,
    "annoying" => -0.6,
    "ugly" => -0.6,
    "slow" => -0.4,
    "confusing" => -0.5,
    "fail" => -0.7,
    "failed" => -0.7,
    "problem" => -0.5,
    "issue" => -0.3,
    "refund" => -0.6,
    "angry" => -0.8
  }

  @doc "Lowercase word tokens (letters/digits/apostrophes)."
  def tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> then(fn s -> Regex.scan(~r/[a-z0-9']+/, s) end)
    |> List.flatten()
  end

  def tokenize(_), do: []

  @doc "Content words: tokens minus stopwords, length > 2."
  def content_words(text) do
    tokenize(text)
    |> Enum.reject(&MapSet.member?(@stopwords, &1))
    |> Enum.filter(&(String.length(&1) > 2))
  end

  @doc "Safe float division; returns 0.0 when denominator is 0."
  def safe_div(_a, b) when b == 0, do: 0.0
  def safe_div(a, b) when is_number(a) and is_number(b), do: a / b

  @doc "Coerce a value to a non-negative integer (YouTube counts arrive as strings)."
  def to_int(nil), do: 0
  def to_int(v) when is_integer(v) and v >= 0, do: v
  def to_int(v) when is_float(v) and v >= 0, do: trunc(v)

  def to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} when n >= 0 -> n
      _ -> 0
    end
  end

  def to_int(_), do: 0

  @doc "Coerce a value to a float (0.0 fallback)."
  def to_float(v) when is_float(v), do: v
  def to_float(v) when is_integer(v), do: v * 1.0

  def to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  def to_float(_), do: 0.0

  @doc """
  Score the average valence of a piece of text in [-1.0, 1.0] using the
  built-in lexicon. Returns `{score, hits}` where `hits` is the number of
  matched lexicon words. Empty/neutral text scores 0.0.
  """
  def sentiment(text) do
    tokens = tokenize(text)

    {sum, hits} =
      Enum.reduce(tokens, {0.0, 0}, fn tok, {s, h} ->
        case Map.get(@lexicon, tok) do
          nil -> {s, h}
          v -> {s + v, h + 1}
        end
      end)

    score = if hits == 0, do: 0.0, else: sum / hits
    {score, hits}
  end

  @doc "Mean of a list of numbers (0.0 for empty)."
  def mean([]), do: 0.0
  def mean(list) when is_list(list), do: Enum.sum(list) / length(list)

  @doc "Round a float to `places` decimal places."
  def round_to(value, places) do
    factor = :math.pow(10, places)
    Float.round(value * factor) / factor
  end
end
