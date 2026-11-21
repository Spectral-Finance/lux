defmodule Lux.Prisms.YouTube.Util do
  @moduledoc """
  Shared helpers for the YouTube Content Intelligence prisms (lux issue #69).

  Pure, deterministic text/number utilities ported from the reference
  analytics/optimizer design: tokenization, stopword/power-word sets,
  safe division, ISO-8601 duration parsing, and engagement scoring.
  """

  @stopwords MapSet.new([
    "the", "a", "an", "and", "or", "but", "of", "to", "in", "on", "for",
    "with", "is", "are", "was", "were", "be", "this", "that", "it", "as",
    "at", "by", "from", "your", "you", "how", "what", "why", "i"
  ])

  @power_words MapSet.new([
    "free", "new", "best", "top", "ultimate", "secret", "proven", "fast",
    "easy", "complete", "guide", "how", "tips", "tricks", "review", "vs",
    "insane", "powerful", "simple", "instant", "exclusive", "revealed"
  ])

  @doc "Lowercase word tokens (letters/digits/apostrophes)."
  def tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> then(fn s -> Regex.scan(~r/[a-z0-9']+/, s) end)
    |> List.flatten()
  end

  @doc "Content words: tokens minus stopwords, length > 2."
  def content_words(text) do
    tokenize(text)
    |> Enum.reject(&MapSet.member?(@stopwords, &1))
    |> Enum.filter(&(String.length(&1) > 2))
  end

  @doc "True if any token is a heuristic 'power word'."
  def has_power_word?(tokens) when is_list(tokens) do
    Enum.any?(tokens, &MapSet.member?(@power_words, &1))
  end

  def has_power_word?(text) when is_binary(text) do
    text |> tokenize() |> has_power_word?()
  end

  @doc "Safe float division; returns 0.0 when denominator is 0."
  def safe_div(_a, b) when b == 0, do: 0.0
  def safe_div(a, b) when is_number(a) and is_number(b), do: a / b

  @doc """
  Parse an ISO-8601 duration (e.g. `PT1H2M3S`, `PT45S`, `P1DT2H`) into seconds.
  Returns 0.0 for empty/invalid input.
  """
  def parse_iso8601_duration(value) when is_binary(value) do
    if String.starts_with?(value, "P") do
      [date_part, time_part] = split_duration(value)
      total = parse_date_part(date_part) + parse_time_part(time_part)
      total
    else
      0.0
    end
  end

  def parse_iso8601_duration(_), do: 0.0

  defp split_duration(value) do
    body = String.slice(value, 1..-1//1)

    case String.split(body, "T", parts: 2) do
      [date] -> [date, ""]
      [date, time] -> [date, time]
      _ -> ["", ""]
    end
  end

  defp parse_date_part(part) do
    case Regex.run(~r/(\d+)D/, part) do
      [_, days] -> to_float(days) * 86_400.0
      _ -> 0.0
    end
  end

  defp parse_time_part(part) do
    units = %{"H" => 3600.0, "M" => 60.0, "S" => 1.0}

    ~r/(\d+(?:\.\d+)?)([HMS])/
    |> Regex.scan(part)
    |> Enum.reduce(0.0, fn [_, num, unit], acc ->
      acc + to_float(num) * Map.get(units, unit, 0.0)
    end)
  end

  defp to_float(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  @doc """
  Map a raw engagement rate to a 0-100 score (4% engagement ≈ 100).
  """
  def engagement_score(rate) when is_number(rate) do
    rate
    |> Kernel./(0.04)
    |> Kernel.*(100.0)
    |> max(0.0)
    |> min(100.0)
  end

  @doc "Mean of a list of numbers (0.0 for empty)."
  def mean([]), do: 0.0
  def mean(list) when is_list(list), do: Enum.sum(list) / length(list)

  @doc "Population standard deviation (0.0 for <2 samples)."
  def pstdev(list) when is_list(list) and length(list) < 2, do: 0.0

  def pstdev(list) when is_list(list) do
    m = mean(list)
    variance = list |> Enum.map(&(:math.pow(&1 - m, 2))) |> Enum.sum() |> Kernel./(length(list))
    :math.sqrt(variance)
  end

  @doc "Median of a list of numbers (0.0 for empty)."
  def median([]), do: 0.0

  def median(list) when is_list(list) do
    sorted = Enum.sort(list)
    n = length(sorted)
    mid = div(n, 2)

    if rem(n, 2) == 1 do
      Enum.at(sorted, mid)
    else
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    end
  end
end