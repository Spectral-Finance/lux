defmodule Lux.Integrations.Telegram.Analytics do
  @moduledoc """
  Telegram channel analytics engine.

  Provides growth tracking, engagement metrics, message performance
  ranking, report generation, sentiment trend analysis, and
  multi-channel comparison for Telegram channels managed by bots.

  All functions operate on raw message/event maps so the module
  stays free of external API calls - testing is straightforward
  with plain data.
  """

  # -------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------

  @doc """
  Track channel growth over a time window.

  Returns the net change, start/end counts, and a day-by-day histogram.
  """
  @spec analyze_growth([map()], [map()], String.t()) :: map()
  def analyze_growth(members, messages \\ [], period \\ "7d") do
    {start_dt, end_dt} = _parse_period(period)

    joined =
      members
      |> Enum.count(fn m ->
        joined_at = _parse_date(m[:joined_at] || m[:date])
        joined_at && NaiveDateTime.compare(joined_at, end_dt) != :gt and NaiveDateTime.compare(joined_at, start_dt) >= :lt
      end)

    churned = _count_churned(members, messages, start_dt)
    daily = _daily_member_counts(members, start_dt, end_dt)

    %{
      period: period,
      start_date: start_dt,
      end_date: end_dt,
      start_count: _total_unique_members(members),
      end_count: _total_unique_members(members) - churned + joined,
      net_change: joined - churned,
      new_members: joined,
      churned_members: churned,
      daily_breakdown: daily
    }
  end

  @doc """
  Compute engagement metrics for a channel.

  Returns average replies per message, average forwards, average views,
  reply rate, and an overall engagement score (0-100).
  """
  @spec engagement_metrics([map()]) :: map()
  def engagement_metrics(messages) when is_list(messages) do
    non_empty = Enum.filter(messages, &( &1[:text] != "" and &1[:text] != nil))
    count = max(length(non_empty), 1)

    total_replies = Enum.sum(Enum.map(non_empty, fn m -> _reply_count(m) end))
    total_forwards = Enum.sum(Enum.map(non_empty, fn m -> m[:forwards] || 0 end))
    total_views = Enum.sum(Enum.map(non_empty, fn m -> m[:views] || 0 end))

    avg_replies = total_replies / count
    avg_forwards = total_forwards / count
    avg_views = total_views / count

    replied_count = Enum.count(non_empty, fn m -> _reply_count(m) > 0 end)
    reply_rate = replied_count / count

    engagement_score =
      avg_replies * 15 + reply_rate * 40 + min(avg_forwards * 10, 25) + min(avg_views / 100, 20)
      |> min(100)
      |> max(0)
      |> round()

    %{
      message_count: count,
      average_replies_per_message: Float.round(avg_replies, 2),
      average_forwards: Float.round(avg_forwards, 2),
      average_views: Float.round(avg_views, 2),
      reply_rate: Float.round(reply_rate, 4),
      replied_messages: replied_count,
      total_forwards: total_forwards,
      total_views: total_views,
      engagement_score: engagement_score
    }
  end

  @doc """
  Rank messages by performance.

  Accepts a `:sort_by` key (`:views`, `:replies`, `:forwards`, `:engagement`).
  Returns the top-N messages (default 10).
  """
  @spec message_performance([map()], %{optional(:sort_by) => atom(), optional(:limit) => integer()}) :: [map()]
  def message_performance(messages, opts \\ %{}) do
    sort_by = Map.get(opts, :sort_by, :engagement)
    limit = Map.get(opts, :limit, 10)

    ranked =
      messages
      |> Enum.map(fn m ->
        score = _performance_score(m, sort_by)
        Map.put(m, :score, score)
      end)
      |> Enum.sort_by(&( &1[:score]), :desc)
      |> Enum.take(limit)

    Enum.map(ranked, fn m ->
      %{
        message_id: m[:id],
        author: _author_label(m[:from]),
        text_preview: _truncate(m[:text], 80),
        score: m[:score],
        views: m[:views] || 0,
        replies: _reply_count(m),
        forwards: m[:forwards] || 0
      }
    end)
  end

  @doc """
  Generate a time-range report.

  `period` accepts `"daily"`, `"weekly"`, or `"monthly"`.
  Returns a summary suitable for sending to a Telegram chat.
  """
  @spec generate_report([map()], [map()], String.t()) :: map()
  def generate_report(messages, members \\ [], period \\ "weekly") do
    eng = engagement_metrics(messages)
    growth = analyze_growth(members, messages, _period_to_range(period))
    top = message_performance(messages, %{sort_by: :engagement, limit: 5})
    sentiment = sentiment_trend(messages)

    %{
      period: period,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      engagement: eng,
      growth: growth,
      top_messages: top,
      sentiment: sentiment,
      summary_text: _format_summary(eng, growth, top, sentiment, period)
    }
  end

  @doc """
  Analyse sentiment trends using keyword matching.

  Returns positive/negative/neutral counts and a trend direction.
  """
  @spec sentiment_trend([map()], %{optional(:positive) => [String.t()], optional(:negative) => [String.t()]}) :: map()
  def sentiment_trend(messages, opts \\ %{}) do
    positive_words = Map.get(opts, :positive, default_positive_words())
    negative_words = Map.get(opts, :negative, default_negative_words())

    classified =
      messages
      |> Enum.map(fn m ->
        text = String.downcase(m[:text] || "")
        pos = _match_count(text, positive_words)
        neg = _match_count(text, negative_words)
        cond do
          pos > neg -> :positive
          neg > pos -> :negative
          pos > 0 and neg > 0 -> :mixed
          true -> :neutral
        end
      end)

    counts = Enum.group_by(classified, &( &1), &(length/1))
    total = length(classified)

    positive_pct = Map.get(counts, :positive, 0) / max(total, 1)
    negative_pct = Map.get(counts, :negative, 0) / max(total, 1)

    trend =
      cond do
        positive_pct > 0.5 -> :positive
        negative_pct > 0.4 -> :negative
        true -> :neutral
      end

    %{
      total_messages_analyzed: total,
      counts: %{
        positive: Map.get(counts, :positive, 0),
        negative: Map.get(counts, :negative, 0),
        neutral: Map.get(counts, :neutral, 0),
        mixed: Map.get(counts, :mixed, 0)
      },
      percentages: %{
        positive: Float.round(positive_pct, 4),
        negative: Float.round(negative_pct, 4),
        neutral: Float.round(Map.get(counts, :neutral, 0) / max(total, 1), 4),
        mixed: Float.round(Map.get(counts, :mixed, 0) / max(total, 1), 4)
      },
      trend: trend
    }
  end

  @doc """
  Compare multiple channels side by side.

  `channels` is a list of `%{name: ..., messages: [...], members: [...]}`.
  """
  @spec compare_channels([map()]) :: [map()]
  def compare_channels(channels) when is_list(channels) do
    Enum.map(channels, fn ch ->
      eng = engagement_metrics(ch[:messages] || [])
      growth = analyze_growth(ch[:members] || [], ch[:messages] || [])
      sent = sentiment_trend(ch[:messages] || [])

      %{
        name: ch[:name],
        message_count: length(ch[:messages] || []),
        member_count: _total_unique_members(ch[:members] || []),
        engagement: eng,
        growth: growth,
        sentiment: sent,
        composite_score: _composite_score(eng, growth, sent)
      }
    end)
    |> Enum.sort_by(&( &1[:composite_score]), :desc)
  end

  # -------------------------------------------------------------------
  # Private helpers
  # -------------------------------------------------------------------

  defp _parse_period("7d"), do: {_ago_days(7), DateTime.utc_now()}
  defp _parse_period("30d"), do: {_ago_days(30), DateTime.utc_now()}
  defp _parse_period("1d"), do: {_ago_days(1), DateTime.utc_now()}
  defp _parse_period(p) when is_binary(p), do: {_ago_days(7), DateTime.utc_now()}

  defp _ago_days(n) do
    DateTime.utc_now()
    |> DateTime.add(-n * 86_400, :second)
    |> NaiveDateTime.truncate(:microsecond)
  end

  defp _period_to_range("daily"), do: "1d"
  defp _period_to_range("weekly"), do: "7d"
  defp _period_to_range("monthly"), do: "30d"
  defp _period_to_range(p) when is_binary(p), do: p

  defp _count_churned(members, messages, start_dt) do
    members
    |> Enum.count(fn member ->
      last_activity = _last_message_date(member, messages)
      last_activity && NaiveDateTime.compare(last_activity, start_dt) == :lt
    end)
  end

  defp _last_message_date(member, messages) do
    member_ids = [member[:id], member[:username]]

    messages
    |> Enum.filter(fn m ->
      m_from = m[:from] || %{}
      m_from[:id] in member_ids or m_from[:username] in member_ids
    end)
    |> Enum.map(fn m -> _parse_date(m[:date]) end)
    |> Enum.filter(&( &1))
    |> Enum.max_by(fn d -> d end, fn -> nil end)
  end

  defp _daily_member_counts(members, start_dt, end_dt) do
    days = Date.range(start_dt.date, end_dt.date) |> Enum.take(31)

    Enum.map(days, fn day ->
      dt = NaiveDateTime.new!(day, ~T[00:00:00])
      count =
        members
        |> Enum.count(fn m ->
          joined = _parse_date(m[:joined_at] || m[:date])
          joined && NaiveDateTime.compare(joined, dt) != :gt
        end)

      %{date: day, count: count}
    end)
  end

  defp _total_unique_members(members) do
    members
    |> Enum.map(&( &1[:id]))
    |> Enum.uniq()
    |> length()
  end

  defp _author_label(nil), do: "unknown"
  defp _author_label(%{username: u}) when is_binary(u) and u != "", do: "@#{u}"
  defp _author_label(%{first_name: n}) when is_binary(n) and n != "", do: n
  defp _author_label(_), do: "unknown"

  defp _truncate(text, max_len) when is_binary(text) and byte_size(text) <= max_len, do: text
  defp _truncate(text, max_len) when is_binary(text), do: String.slice(text, 0, max_len) <> "..."
  defp _truncate(_, _), do: ""

  defp _performance_score(m, :views), do: m[:views] || 0
  defp _performance_score(m, :replies), do: _reply_count(m)
  defp _performance_score(m, :forwards), do: m[:forwards] || 0
  defp _performance_score(m, :engagement) do
    views = m[:views] || 1
    replies = _reply_count(m)
    forwards = m[:forwards] || 0
    replies * 10 + forwards * 5 + div(views, 10)
  end

  defp _reply_count(m) do
    case m[:replies] do
      replies when is_list(replies) -> length(replies)
      _ -> 0
    end
  end

  defp _match_count(text, words) do
    Enum.count(words, fn w -> String.contains?(text, String.downcase(w)) end)
  end

  defp _parse_date(nil), do: nil
  defp _parse_date(""), do: nil

  defp _parse_date(str) when is_binary(str) do
    case NaiveDateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      {:ok, dt} -> dt
      {:error, _} ->
        case DateTime.from_iso8601(str) do
          {:ok, dt, _} -> DateTime.to_naive(dt)
          _ -> nil
        end
    end
  end

  defp _parse_date(%Date{} = d), do: NaiveDateTime.new!(d, ~T[00:00:00])
  defp _parse_date(%NaiveDateTime{} = dt), do: dt
  defp _parse_date(%DateTime{} = dt), do: DateTime.to_naive(dt)
  defp _parse_date(_), do: nil

  defp _format_summary(eng, growth, top, sentiment, period) do
    lines = [
      "=== #{String.capitalize(period)} Report ===",
      "",
      "Engagement:",
      "  Avg replies/message: #{eng[:average_replies_per_message]}",
      "  Reply rate: #{Float.round(eng[:reply_rate] * 100, 2)}%",
      "  Engagement score: #{eng[:engagement_score]}/100",
      "",
      "Growth (#{growth[:period]}):",
      "  Net change: #{growth[:net_change]}",
      "  New: #{growth[:new_members]}  Churned: #{growth[:churned_members]}",
      "",
      "Top messages:",
      Enum.map(top, fn t ->
        "  - @#{t[:author]} score=#{t[:score]} (#{t[:replies]} replies, #{t[:forwards]} fwd)"
      end),
      "",
      "Sentiment: #{sentiment[:trend]} (#{Float.round(sentiment[:percentages][:positive] * 100, 1)}% positive)"
    ]

    lines |> Enum.join("\n")
  end

  defp _composite_score(eng, _growth, sentiment) do
    (eng[:engagement_score] || 0) * 0.5
    + cond do
      sentiment[:trend] == :positive -> 30
      sentiment[:trend] == :mixed -> 15
      true -> 5
    end
    + min((eng[:average_views] || 0) / 10, 20)
  end

  defp max(a, b), do: if a > b, do: a, else: b
  defp min(a, b), do: if a < b, do: a, else: b

  defp default_positive_words do
    [
      "great", "awesome", "excited", "bullish", "love", "amazing",
      "impressive", "solid", "strong", "breakthrough", "success",
      "profit", "gain", "win", "fantastic", "excellent", "good",
      "nice", "well", "happy", "pleased", "recommend", "trust",
      "grateful", "thankful", "inspiring", "motivating", "powerful",
      "game-changing", "revolutionary", "innovative", "promising"
    ]
  end

  defp default_negative_words do
    [
      "bad", "terrible", "awful", "horrible", "disappointing",
      "scam", "fraud", "rug", "dump", "crash", "loss", "fail",
      "worst", "hate", "angry", "frustrated", "annoying", "risky",
      "dangerous", "unstable", "broken", "bug", "exploit", "hack",
      "theft", "steal", "fake", "phishing", "malware", "virus",
      "toxic", "spam", "garbage", "trash", "useless", "pointless"
    ]
  end
end
