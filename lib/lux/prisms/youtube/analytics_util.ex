defmodule Lux.Prisms.YouTube.AnalyticsUtil do
  @moduledoc """
  Shared analytics helpers for the YouTube Analytics prisms (lux issue #71).

  Pure, deterministic math and parsing utilities used by the channel analytics,
  video performance, audience engagement, prediction, posting-time, trending and
  recommendation prisms:

    * YouTube count coercion — `viewCount`/`likeCount` arrive as **strings** in
      `videos.list` payloads, so every helper is defensive about `nil`, strings
      and missing keys.
    * Descriptive statistics — mean, median, population stdev, percentiles.
    * ISO-8601 parsing — `contentDetails.duration` (`PT1H2M3S`) and
      `snippet.publishedAt` (`2026-01-01T12:00:00Z`).
    * Engagement maths — engagement rate, like ratio, comment ratio and a
      bounded 0-100 engagement score.
    * Key-agnostic map access — works with atom-keyed maps (tests, internal
      callers) *and* string-keyed maps (raw `videos.list` JSON).

  No network calls. Everything here is referentially transparent so the
  analytics prisms stay unit-testable and side-effect free.
  """

  @typedoc "A raw `videos.list` item, atom- or string-keyed."
  @type video_item :: map()

  @typedoc "Normalised per-video metrics produced by `video_metrics/1`."
  @type video_metrics :: %{
          required(:id) => String.t(),
          required(:title) => String.t(),
          required(:published_at) => String.t(),
          required(:views) => integer(),
          required(:likes) => integer(),
          required(:comments) => integer(),
          required(:duration_seconds) => float()
        }

  # --------------------------------------------------------------------------- #
  # Key-agnostic map access
  # --------------------------------------------------------------------------- #
  @doc """
  Read `key` from `map`, accepting either an atom or a string key.

  Raw YouTube payloads are string-keyed (JSON) while tests and internal callers
  usually use atom keys. This makes every prism indifferent to both.

      iex> AnalyticsUtil.fetch_key(%{"title" => "Hi"}, :title)
      "Hi"

      iex> AnalyticsUtil.fetch_key(%{title: "Hi"}, "title")
      "Hi"
  """
  @spec fetch_key(map(), atom() | String.t()) :: any()
  def fetch_key(map, key) when is_map(map) and is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  def fetch_key(map, key) when is_map(map) and is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, existing_atom(key))
    end
  end

  def fetch_key(_map, _key), do: nil

  @doc """
  Walk a path of keys through nested maps, tolerating atom/string key mixes.

      iex> AnalyticsUtil.dig(%{"snippet" => %{"title" => "Hi"}}, [:snippet, :title])
      "Hi"
  """
  @spec dig(any(), [atom() | String.t()]) :: any()
  def dig(value, []), do: value
  def dig(map, [key | rest]) when is_map(map), do: map |> fetch_key(key) |> dig(rest)
  def dig(_value, _path), do: nil

  defp existing_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  # --------------------------------------------------------------------------- #
  # Coercion
  # --------------------------------------------------------------------------- #
  @doc "Coerce a YouTube count to a non-negative integer (`nil`/`\"12\"`/`12.0` -> `0`/`12`/`12`)."
  @spec to_int(any()) :: integer()
  def to_int(nil), do: 0
  def to_int(value) when is_integer(value) and value >= 0, do: value
  def to_int(value) when is_float(value) and value >= 0, do: trunc(value)

  def to_int(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, _rest} when n >= 0 -> n
      _ -> 0
    end
  end

  def to_int(_value), do: 0

  @doc "Coerce a value to a float (0.0 fallback)."
  @spec to_float(any()) :: float()
  def to_float(value) when is_float(value), do: value
  def to_float(value) when is_integer(value), do: value * 1.0

  def to_float(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {f, _rest} -> f
      :error -> 0.0
    end
  end

  def to_float(_value), do: 0.0

  # --------------------------------------------------------------------------- #
  # Descriptive statistics
  # --------------------------------------------------------------------------- #
  @doc "Arithmetic mean of a list of numbers (0.0 for an empty list)."
  @spec mean([number()]) :: float()
  def mean([]), do: 0.0
  def mean(list) when is_list(list), do: Enum.sum(list) / length(list)

  @doc "Median of a list of numbers (0.0 for an empty list)."
  @spec median([number()]) :: float()
  def median([]), do: 0.0

  def median(list) when is_list(list) do
    sorted = Enum.sort(list)
    n = length(sorted)

    if rem(n, 2) == 1 do
      sorted |> Enum.at(div(n, 2)) |> to_float()
    else
      lower = sorted |> Enum.at(div(n, 2) - 1) |> to_float()
      upper = sorted |> Enum.at(div(n, 2)) |> to_float()
      (lower + upper) / 2
    end
  end

  @doc "Population standard deviation (0.0 for fewer than two samples)."
  @spec stdev([number()]) :: float()
  def stdev(list) when is_list(list) and length(list) < 2, do: 0.0

  def stdev(list) when is_list(list) do
    mu = mean(list)
    variance = list |> Enum.map(&(:math.pow(to_float(&1) - mu, 2))) |> mean()
    :math.sqrt(variance)
  end

  @doc """
  Linear-interpolation percentile of a list of numbers.

  `p` is a fraction in `[0.0, 1.0]`; `percentile([1, 2, 3, 4], 0.5)` is `2.5`.
  Returns 0.0 for an empty list.
  """
  @spec percentile([number()], float()) :: float()
  def percentile([], _p), do: 0.0

  def percentile(list, p) when is_list(list) do
    sorted = list |> Enum.map(&to_float/1) |> Enum.sort()
    p = p |> to_float() |> max(0.0) |> min(1.0)
    n = length(sorted)

    case n do
      1 -> hd(sorted)
      _ ->
        rank = p * (n - 1)
        lower = trunc(rank)
        upper = min(lower + 1, n - 1)
        weight = rank - lower
        Enum.at(sorted, lower) * (1 - weight) + Enum.at(sorted, upper) * weight
    end
  end

  @doc "Safe division: 0.0 when the denominator is 0 (or not a number)."
  @spec safe_div(number(), number()) :: float()
  def safe_div(_a, b) when b in [0, 0.0], do: 0.0
  def safe_div(a, b) when is_number(a) and is_number(b), do: to_float(a) / to_float(b)
  def safe_div(_a, _b), do: 0.0

  @doc "Round a float to `places` decimal places."
  @spec round_to(number(), non_neg_integer()) :: float()
  def round_to(value, places) do
    factor = :math.pow(10, places)
    Float.round(to_float(value) * factor) / factor
  end

  # --------------------------------------------------------------------------- #
  # ISO-8601 parsing
  # --------------------------------------------------------------------------- #
  @iso_units %{"H" => 3600, "M" => 60, "S" => 1}

  @doc """
  Parse an ISO-8601 duration (`PT1H2M3S`, `PT45S`, `P1DT2H`) into seconds.

  Returns 0.0 for anything unparseable, so a missing `contentDetails.duration`
  never breaks an aggregation.

      iex> AnalyticsUtil.parse_duration("PT1H2M3S")
      3723.0

      iex> AnalyticsUtil.parse_duration("PT15M33S")
      933.0
  """
  @spec parse_duration(any()) :: float()
  def parse_duration(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      not String.starts_with?(value, "P") -> 0.0
      true -> value |> String.slice(1..-1//1) |> split_duration()
    end
  end

  def parse_duration(_value), do: 0.0

  defp split_duration(""), do: 0.0

  defp split_duration(body) do
    {date_part, time_part} =
      case String.split(body, "T", parts: 2) do
        [date] -> {date, nil}
        [date, time] -> {date, time}
      end

    days = parse_date_part(date_part)
    seconds = if time_part, do: parse_time_part(time_part), else: 0.0
    days * 86400 + seconds
  end

  defp parse_date_part(""), do: 0.0

  defp parse_date_part(date_part) do
    {num, unit} = split_number(date_part)

    case unit do
      "D" -> to_float(num)
      _ -> 0.0
    end
  end

  defp parse_time_part(""), do: 0.0

  defp parse_time_part(time_part) do
    time_part
    |> String.graphemes()
    |> Enum.reduce({0.0, ""}, fn
      char, {total, num} when char in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "."] ->
        {total, num <> char}

      char, {total, num} ->
        case Map.get(@iso_units, char) do
          nil -> {total, ""}
          unit -> {total + to_float(num) * unit, ""}
        end
    end)
    |> elem(0)
  end

  defp split_number(string) do
    {num, unit} =
      string
      |> String.graphemes()
      |> Enum.split_while(&(&1 != "D" and &1 != "H" and &1 != "M" and &1 != "S"))

    {Enum.join(num), Enum.join(unit)}
  end

  @doc """
  Parse an ISO-8601 UTC timestamp (`2026-01-01T12:00:00Z`) into Unix epoch seconds.

  Returns `nil` when the value is missing or unparseable so callers can decide
  how to degrade (velocity calculations treat unknown age as 0 days).
  """
  @spec parse_timestamp(any()) :: integer() | nil
  def parse_timestamp(value) when is_binary(value) do
    value = value |> String.trim() |> String.replace_trailing("Z", "")

    case NaiveDateTime.from_iso8601(value) do
      {:ok, naive} -> naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
      _ -> nil
    end
  end

  def parse_timestamp(_value), do: nil

  @doc """
  Age of a `publishedAt` timestamp in days, relative to `now_epoch`.

  Unknown/unparseable timestamps yield 0.0; future timestamps also yield 0.0 so
  velocity never goes negative.
  """
  @spec age_days(any(), integer()) :: float()
  def age_days(published_at, now_epoch) do
    case parse_timestamp(published_at) do
      nil -> 0.0
      epoch -> max(0.0, (now_epoch - epoch) / 86400.0)
    end
  end

  # --------------------------------------------------------------------------- #
  # Engagement maths
  # --------------------------------------------------------------------------- #
  @doc """
  Engagement rate: `(likes + comments) / views`.

  This is the fraction of viewers who took an explicit action. 0.0 when the
  video has no views.
  """
  @spec engagement_rate(number(), number(), number()) :: float()
  def engagement_rate(views, likes, comments) do
    safe_div(to_float(likes) + to_float(comments), views)
  end

  @doc "Like ratio: `likes / views`."
  @spec like_ratio(number(), number()) :: float()
  def like_ratio(views, likes), do: safe_div(likes, views)

  @doc "Comment ratio: `comments / views`."
  @spec comment_ratio(number(), number()) :: float()
  def comment_ratio(views, comments), do: safe_div(comments, views)

  @doc """
  Map a raw engagement rate onto a bounded 0-100 score.

  Anchored so that a 4% engagement rate (`0.04`) scores 100 — a strong result
  for a mid-size channel — and saturates beyond it.
  """
  @spec engagement_score(number()) :: float()
  def engagement_score(rate) do
    rate |> to_float() |> Kernel./(0.04) |> Kernel.*(100.0) |> max(0.0) |> min(100.0)
  end

  # --------------------------------------------------------------------------- #
  # Video normalisation
  # --------------------------------------------------------------------------- #
  @doc """
  Normalise a raw `videos.list` item into a `video_metrics` map.

  Accepts both atom- and string-keyed payloads and tolerates missing
  `snippet`/`statistics`/`contentDetails` sections.

      iex> AnalyticsUtil.video_metrics(%{
      ...>   "id" => "v1",
      ...>   "snippet" => %{"title" => "How to bake", "publishedAt" => "2026-01-01T00:00:00Z"},
      ...>   "statistics" => %{"viewCount" => "1000", "likeCount" => "50", "commentCount" => "5"},
      ...>   "contentDetails" => %{"duration" => "PT10M"}
      ...> }).views
      1000
  """
  @spec video_metrics(video_item()) :: video_metrics()
  def video_metrics(item) when is_map(item) do
    %{
      id: item |> fetch_key(:id) |> to_string(),
      title: item |> dig([:snippet, :title]) |> to_string(),
      published_at: item |> dig([:snippet, :publishedAt]) |> to_string(),
      views: item |> dig([:statistics, :viewCount]) |> to_int(),
      likes: item |> dig([:statistics, :likeCount]) |> to_int(),
      comments: item |> dig([:statistics, :commentCount]) |> to_int(),
      duration_seconds: item |> dig([:contentDetails, :duration]) |> parse_duration()
    }
  end

  @doc """
  Enrich normalised metrics with derived engagement fields.

  Adds `:engagement_rate`, `:like_ratio`, `:comment_ratio` and
  `:engagement_score` without mutating the input map.
  """
  @spec enrich(video_metrics()) :: map()
  def enrich(%{} = metrics) do
    views = Map.get(metrics, :views, 0)
    likes = Map.get(metrics, :likes, 0)
    comments = Map.get(metrics, :comments, 0)
    rate = engagement_rate(views, likes, comments)

    metrics
    |> Map.put(:engagement_rate, round_to(rate, 6))
    |> Map.put(:like_ratio, round_to(like_ratio(views, likes), 6))
    |> Map.put(:comment_ratio, round_to(comment_ratio(views, comments), 6))
    |> Map.put(:engagement_score, round_to(engagement_score(rate), 2))
  end

  @doc """
  Extract the uploads-playlist id from a `channels.list` item.

      iex> AnalyticsUtil.uploads_playlist(%{
      ...>   "contentDetails" => %{"relatedPlaylists" => %{"uploads" => "UU123"}}
      ...> })
      "UU123"
  """
  @spec uploads_playlist(map()) :: String.t()
  def uploads_playlist(item) when is_map(item) do
    item |> dig([:contentDetails, :relatedPlaylists, :uploads]) |> to_string()
  end

  @doc "Extract video ids from a `playlistItems.list` payload, skipping blanks."
  @spec playlist_video_ids(map()) :: [String.t()]
  def playlist_video_ids(payload) when is_map(payload) do
    payload
    |> fetch_key(:items)
    |> case do
      items when is_list(items) ->
        items
        |> Enum.map(&dig(&1, [:contentDetails, :videoId]))
        |> Enum.reject(&(is_nil(&1) or &1 == ""))

      _ ->
        []
    end
  end

  @doc "Normalise a batch of raw `videos.list` items into enriched metrics."
  @spec metrics_batch([video_item()]) :: [map()]
  def metrics_batch(items) when is_list(items) do
    items |> Enum.map(&video_metrics/1) |> Enum.map(&enrich/1)
  end

  @doc """
  Format a number of seconds as `H:MM:SS` (or `M:SS` under an hour).

      iex> AnalyticsUtil.format_duration(3723)
      "1:02:03"
  """
  @spec format_duration(number()) :: String.t()
  def format_duration(seconds) do
    total = seconds |> to_float() |> round() |> max(0)
    hours = div(total, 3600)
    minutes = div(rem(total, 3600), 60)
    secs = rem(total, 60)

    if hours > 0 do
      "#{hours}:#{pad(minutes)}:#{pad(secs)}"
    else
      "#{minutes}:#{pad(secs)}"
    end
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")

  @doc """
  Human-readable compact count (`1500` -> `"1.5K"`, `2_400_000` -> `"2.4M"`).

      iex> AnalyticsUtil.compact(1500)
      "1.5K"
  """
  @spec compact(number()) :: String.t()
  def compact(n) when n >= 1_000_000_000, do: trim_zero(to_float(n) / 1_000_000_000) <> "B"
  def compact(n) when n >= 1_000_000, do: trim_zero(to_float(n) / 1_000_000) <> "M"
  def compact(n) when n >= 1_000, do: trim_zero(to_float(n) / 1_000) <> "K"
  def compact(n) when is_integer(n), do: Integer.to_string(n)
  def compact(n), do: trim_zero(n)

  defp trim_zero(value) do
    value
    |> Float.round(1)
    |> :erlang.float_to_binary(decimals: 1)
    |> String.replace(~r/\.0$/, "")
  end
end