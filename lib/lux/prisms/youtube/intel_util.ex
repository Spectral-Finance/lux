defmodule Lux.Prisms.YouTube.IntelUtil do
  @moduledoc """
  Shared, pure helpers for the YouTube Content-Intelligence prisms
  (lux issue #78 — "YouTube Prism implementation").

  These are deterministic numeric / text utilities used by the video, channel,
  discovery, monetization and SEO prisms: safe coercion of YouTube's
  string-encoded counts, ISO-8601 duration parsing, percentage / ratio math,
  percentile-friendly statistics, and view-weighted keyword extraction.

  No network calls, no clock reads, no global state — callers fetch raw
  `videos.list` / `channels.list` payloads via their YouTube client and pass
  the parsed maps in, which keeps every prism unit-testable and side-effect
  free. Text tokenization reuses `Lux.Prisms.YouTube.Util` so stopword and
  lexicon behaviour stays consistent across the whole YouTube prism family.
  """

  alias Lux.Prisms.YouTube.Util

  @doc """
  Read `key` from a map that may use either string keys (raw YouTube Data API
  v3 JSON) or atom keys (hand-built test fixtures). Returns `nil` when absent.
  """
  def get_field(map, key) when is_map(map) and is_binary(key) do
    case Map.get(map, key) do
      nil -> Map.get(map, String.to_atom(key))
      value -> value
    end
  end

  def get_field(_map, _key), do: nil

  @doc """
  Return the nested object at `name` (`"snippet"`, `"statistics"`,
  `"contentDetails"`, ...), tolerating string or atom keys. Returns `%{}`
  when the section is missing or not a map.
  """
  def section(map, name) when is_binary(name) do
    case get_field(map, name) do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  @doc "Percentage `part / whole * 100` rounded to 2 dp; 0.0 when whole is 0."
  def percent(_part, whole) when whole == 0, do: 0.0

  def percent(part, whole) when is_number(part) and is_number(whole) do
    round_to(part / whole * 100.0, 2)
  end

  @doc "Median of a list of numbers (0.0 for an empty list)."
  def median([]), do: 0.0

  def median(list) when is_list(list) do
    sorted = Enum.sort(list)
    n = length(sorted)
    mid = div(n, 2)

    if rem(n, 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2.0
    else
      Enum.at(sorted, mid) * 1.0
    end
  end

  @doc "Clamp `x` into the inclusive range `[lo, hi]`."
  def clamp(x, lo, _hi) when x < lo, do: lo
  def clamp(x, _lo, hi) when x > hi, do: hi
  def clamp(x, _lo, _hi), do: x

  @doc """
  Convert an ISO-8601 duration (e.g. `"PT4M13S"`, `"PT1H2M3S"`, `"P1DT2H"`)
  into a whole number of seconds. Returns 0 for `nil` / unparseable input.
  """
  def iso8601_to_seconds(nil), do: 0
  def iso8601_to_seconds(""), do: 0

  def iso8601_to_seconds(duration) when is_binary(duration) do
    days = match_int(~r/(\d+)D/, duration)
    hours = match_int(~r/(\d+)H/, duration)
    minutes = match_int(~r/(\d+)M/, duration)
    seconds = match_int(~r/(\d+)S/, duration)

    days * 86_400 + hours * 3_600 + minutes * 60 + seconds
  end

  def iso8601_to_seconds(_), do: 0

  defp match_int(regex, string) do
    case Regex.scan(regex, string) |> List.flatten() |> List.first() do
      nil -> 0
      digits -> digits |> Integer.parse() |> elem(0)
    end
  end

  @doc """
  Extract the 4-digit publication year from an RFC-3339 timestamp
  (`"2024-01-15T10:00:00Z"` -> `2024`). Returns 0 when absent/invalid.
  """
  def parse_year(nil), do: 0

  def parse_year(timestamp) when is_binary(timestamp) do
    timestamp
    |> String.slice(0, 4)
    |> Integer.parse()
    |> case do
      {year, _} when year >= 1900 -> year
      _ -> 0
    end
  end

  def parse_year(_), do: 0

  @doc """
  Rank the most frequent content words in `text`, weighted by occurrence.
  Returns `[{word, count}]` sorted by count desc then word asc (deterministic),
  truncated to `n` entries. Reuses the shared stopword list via `Util`.
  """
  def keywords(text, n) when is_binary(text) and is_integer(n) and n >= 0 do
    text
    |> Util.content_words()
    |> Enum.frequencies()
    |> Enum.sort(fn {w1, c1}, {w2, c2} ->
      if c1 == c2, do: w1 < w2, else: c1 > c2
    end)
    |> Enum.take(n)
  end

  @doc "Round a float to `places` decimal places (delegates to `Util`)."
  def round_to(value, places), do: Util.round_to(value, places)
end