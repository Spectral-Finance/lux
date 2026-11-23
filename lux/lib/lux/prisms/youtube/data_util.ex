defmodule Lux.Prisms.YouTube.DataUtil do
  @moduledoc """
  Shared helpers for the YouTube **Data API** prisms (lux issue #73 —
  "YouTube Prism implementation").

  Pure, deterministic coercion / parsing / ranking utilities used by the
  video, channel, search, engagement, keyword and playlist prisms. Every
  function is side-effect free: no network, no clock, no process state.
  YouTube's JSON encodes counts as *strings* (`"viewCount": "1234"`) and
  durations as ISO-8601 (`"PT1H2M3S"`), so the coercion helpers here are the
  single place that normalises those quirks for the whole prism layer.

  These complement `Lux.Prisms.YouTube.Util` (issue #70, community
  management) — `Util` owns the sentiment/spam lexicon, `DataUtil` owns the
  Data API shape.
  """

  # Title/keyword stopwords. Deliberately small and transparent so keyword
  # extraction is explainable and auditable (no opaque model).
  @stopwords MapSet.new(~w(
    the a an and or but of to in on for with is are was were be been being
    this that these those it its as at by from your you we our their his her
    not no nor so if then than too very can will just about into over under
    after before more most some any each which who whom what when where why
    how all also out up down off again further once here there both few other
    such only own same now get got via vs
  ))

  @doc "Coerce a YouTube count (often a JSON string) to a non-negative integer."
  def to_int(nil), do: 0
  def to_int(v) when is_integer(v) and v >= 0, do: v
  def to_int(v) when is_float(v) and v >= 0, do: trunc(v)

  def to_int(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, _} when n >= 0 -> n
      _ -> 0
    end
  end

  def to_int(_), do: 0

  @doc "Coerce a value to a float (0.0 fallback)."
  def to_float(v) when is_float(v), do: v
  def to_float(v) when is_integer(v), do: v * 1.0

  def to_float(v) when is_binary(v) do
    case Float.parse(String.trim(v)) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  def to_float(_), do: 0.0

  @doc "Safe float division; returns 0.0 when the denominator is 0."
  def safe_div(_a, b) when b == 0, do: 0.0
  def safe_div(a, b) when is_number(a) and is_number(b), do: a / b

  @doc "Round a float to `places` decimal places."
  def round_to(value, places) do
    factor = :math.pow(10, places)
    Float.round(value * factor) / factor
  end

  @doc "Arithmetic mean of a list of numbers (0.0 for an empty list)."
  def mean([]), do: 0.0
  def mean(list) when is_list(list), do: Enum.sum(list) / length(list)

  @doc """
  Parse an ISO-8601 duration into whole seconds.

  Handles the `videos.list` `contentDetails.duration` shape: `PT#H#M#S`,
  e.g. `"PT1H2M3S"` -> `3723`, `"PT45S"` -> `45`, `"PT2M30S"` -> `150`.
  Returns `0` for `nil`, empty, or unparseable input (including day-based
  `P#D` forms, which the Data API does not emit for videos).
  """
  def iso8601_to_seconds(nil), do: 0

  def iso8601_to_seconds(duration) when is_binary(duration) do
    case Regex.run(~r/^P(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$/, duration) do
      [_, hours, minutes, seconds] ->
        to_int(hours) * 3600 + to_int(minutes) * 60 + round(to_float(seconds))

      [_, hours, minutes] ->
        to_int(hours) * 3600 + to_int(minutes) * 60

      [_, hours] ->
        to_int(hours) * 3600

      _ ->
        0
    end
  end

  def iso8601_to_seconds(_), do: 0

  @doc """
  Extract the top-N keywords from a piece of text (title or description).

  Lowercases, tokenises on non-alphanumeric boundaries, drops stopwords and
  tokens of length <= 2, then ranks by descending frequency with ties broken
  alphabetically (ascending) so the output is fully deterministic. Returns a
  list of `%{keyword, count}` maps.
  """
  def keywords(text, limit) when is_integer(limit) and limit > 0 do
    text
    |> tokenize()
    |> Enum.reject(&MapSet.member?(@stopwords, &1))
    |> Enum.filter(&(String.length(&1) > 2))
    |> Enum.frequencies()
    |> Enum.sort(fn {k1, c1}, {k2, c2} ->
      cond do
        c1 > c2 -> true
        c1 < c2 -> false
        true -> k1 <= k2
      end
    end)
    |> Enum.take(limit)
    |> Enum.map(fn {keyword, count} -> %{keyword: keyword, count: count} end)
  end

  def keywords(_text, _limit), do: []

  @doc "Lowercase word tokens (letters/digits/apostrophes)."
  def tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> then(fn s -> Regex.scan(~r/[a-z0-9']+/, s) end)
    |> List.flatten()
  end

  def tokenize(_), do: []

  @doc """
  Rank a list of `%{keyword, count}` maps (or `{keyword, count}` tuples) by
  descending count, ties broken alphabetically. Returns the same shape it was
  given, truncated to `limit`. Accepts either a list or a `keyword => count`
  map (as produced by `Enum.frequencies/1`).
  """
  def rank_keywords(list, limit) when is_list(list) and limit > 0 do
    list
    |> Enum.sort(fn
      {k1, c1}, {k2, c2} ->
        cond do
          c1 > c2 -> true
          c1 < c2 -> false
          true -> k1 <= k2
        end

      %{keyword: k1, count: c1}, %{keyword: k2, count: c2} ->
        cond do
          c1 > c2 -> true
          c1 < c2 -> false
          true -> k1 <= k2
        end
    end)
    |> Enum.take(limit)
  end

  def rank_keywords(map, limit) when is_map(map) and limit > 0 do
    map |> Enum.into([]) |> rank_keywords(limit)
  end

  def rank_keywords(_list, _limit), do: []
end
