defmodule Lux.Integrations.Twitter.Automation do
  @moduledoc """
  Deterministic automation helpers for Twitter/X engagement workflows.

  This module intentionally does not call the Twitter API. It builds schedules,
  engagement action plans, and rate-limited queues that an agent can inspect or
  hand to a transport-specific executor.
  """

  @default_schedule %{
    start_at: "2026-01-01T09:00:00Z",
    interval_minutes: 60,
    per_day_limit: 8,
    timezone: "UTC"
  }

  @default_queue %{
    now: "2026-01-01T00:00:00Z",
    per_window_limit: 15,
    window_minutes: 15,
    review_required_actions: [:direct_message, :unfollow]
  }

  @action_priorities %{
    reply: 90,
    quote: 80,
    repost: 70,
    like: 60,
    follow: 50,
    direct_message: 40,
    unfollow: 30,
    tweet: 20
  }

  @type content_item :: map()
  @type event :: map()
  @type rule :: map()
  @type action_plan :: map()

  @doc """
  Creates a content schedule from draft tweet items.
  """
  @spec schedule_content([content_item()], keyword() | map()) :: map()
  def schedule_content(items, opts \\ %{}) do
    opts = Map.merge(@default_schedule, normalize_options(opts))
    start_at = parse_datetime!(opts.start_at)
    interval_seconds = max(opts.interval_minutes, 1) * 60
    per_day_limit = max(opts.per_day_limit, 1)

    scheduled =
      items
      |> Enum.map(&normalize_content/1)
      |> Enum.sort_by(fn item -> {-item.priority, item.id} end)
      |> Enum.reduce({[], %{}}, fn item, {entries, day_counts} ->
        slot = next_slot(start_at, interval_seconds, per_day_limit, length(entries), day_counts)
        day = Date.to_iso8601(DateTime.to_date(slot))
        entry = build_schedule_entry(item, slot)

        {[entry | entries], Map.update(day_counts, day, 1, &(&1 + 1))}
      end)
      |> elem(0)
      |> Enum.reverse()

    %{
      scheduled: scheduled,
      calendar: content_calendar(scheduled),
      summary: %{
        total_items: length(items),
        scheduled_items: length(scheduled),
        per_day_limit: per_day_limit,
        interval_minutes: opts.interval_minutes,
        timezone: opts.timezone
      }
    }
  end

  @doc """
  Evaluates engagement rules against normalized social events.
  """
  @spec evaluate_rules([event()], [rule()], keyword() | map()) :: map()
  def evaluate_rules(events, rules, opts \\ %{}) do
    opts = normalize_options(opts)
    normalized_events = Enum.map(events, &normalize_event/1)
    normalized_rules = Enum.map(rules, &normalize_rule/1)

    actions =
      normalized_events
      |> Enum.flat_map(fn event ->
        normalized_rules
        |> Enum.filter(&rule_matches?(&1, event, opts))
        |> Enum.map(&build_action(&1, event))
      end)
      |> dedupe_actions()
      |> Enum.sort_by(fn action -> {-action.priority, action.target_id, action.action} end)

    %{
      actions: actions,
      summary: %{
        events: length(normalized_events),
        rules: length(normalized_rules),
        matched_actions: length(actions),
        by_action: actions |> Enum.frequencies_by(& &1.action) |> sort_counts()
      }
    }
  end

  @doc """
  Turns action plans into a rate-limited execution queue.
  """
  @spec queue_actions([action_plan()], keyword() | map()) :: map()
  def queue_actions(actions, opts \\ %{}) do
    opts = Map.merge(@default_queue, normalize_options(opts))
    now = parse_datetime!(opts.now)
    window_seconds = max(opts.window_minutes, 1) * 60
    limit = max(opts.per_window_limit, 1)
    review_actions = MapSet.new(opts.review_required_actions)

    normalized_actions =
      actions
      |> Enum.map(&normalize_action/1)
      |> dedupe_actions()
      |> Enum.sort_by(fn action -> {-action.priority, action.target_id, action.action} end)

    queued =
      normalized_actions
      |> Enum.with_index()
      |> Enum.map(fn {action, index} ->
        window_index = div(index, limit)
        run_at = DateTime.add(now, window_index * window_seconds, :second)

        requires_review =
          action.action in review_actions or Map.get(action, :requires_review, false)

        action
        |> Map.put(:queue_status, if(requires_review, do: :needs_review, else: :queued))
        |> Map.put(:run_at, DateTime.to_iso8601(run_at))
        |> Map.put(:requires_review, requires_review)
      end)

    %{
      queued: queued,
      summary: %{
        input_actions: length(actions),
        queued_actions: Enum.count(queued, &(&1.queue_status == :queued)),
        needs_review: Enum.count(queued, &(&1.queue_status == :needs_review)),
        queue_depth: length(queued),
        estimated_drain_minutes:
          estimated_drain_minutes(length(queued), limit, opts.window_minutes)
      }
    }
  end

  @doc """
  Builds a day/campaign/action summary from scheduled entries.
  """
  @spec content_calendar([map()]) :: map()
  def content_calendar(entries) when is_list(entries) do
    by_day =
      entries
      |> Enum.group_by(fn entry ->
        entry.scheduled_at |> parse_datetime!() |> DateTime.to_date() |> Date.to_iso8601()
      end)
      |> Map.new(fn {day, items} ->
        {day,
         %{
           count: length(items),
           campaigns:
             items
             |> Enum.map(& &1.campaign)
             |> reject_blank()
             |> Enum.frequencies()
             |> sort_counts(),
           actions: items |> Enum.map(& &1.action) |> Enum.frequencies() |> sort_counts()
         }}
      end)

    %{
      by_day: by_day,
      total_days: map_size(by_day),
      total_items: length(entries)
    }
  end

  defp normalize_content(item) when is_map(item) do
    text = fetch_value(item, :text) || fetch_value(item, :body) || ""

    %{
      id: fetch_value(item, :id) || stable_id(text),
      text: text,
      action: normalize_action_name(fetch_value(item, :action) || :tweet),
      campaign: fetch_value(item, :campaign) || "default",
      tags: List.wrap(fetch_value(item, :tags) || []),
      priority: normalize_integer(fetch_value(item, :priority) || 0),
      metadata: fetch_value(item, :metadata) || %{},
      warnings: content_warnings(text)
    }
  end

  defp normalize_event(event) when is_map(event) do
    text = fetch_value(event, :text) || ""

    %{
      id: fetch_value(event, :id) || fetch_value(event, :tweet_id) || stable_id(text),
      type: normalize_event_type(fetch_value(event, :type) || fetch_value(event, :event_type)),
      text: text,
      author_id: fetch_value(event, :author_id) || fetch_value(event, :user_id),
      author_handle: fetch_value(event, :author_handle) || fetch_value(event, :username),
      author_followers: normalize_integer(fetch_value(event, :author_followers) || 0),
      sentiment: normalize_sentiment(fetch_value(event, :sentiment)),
      created_at: fetch_value(event, :created_at),
      tags: List.wrap(fetch_value(event, :tags) || []),
      metadata: fetch_value(event, :metadata) || %{}
    }
  end

  defp normalize_rule(rule) when is_map(rule) do
    %{
      name: fetch_value(rule, :name) || "engagement_rule",
      action: normalize_action_name(fetch_value(rule, :action) || :reply),
      priority:
        normalize_integer(
          fetch_value(rule, :priority) || action_priority(fetch_value(rule, :action))
        ),
      response_template: fetch_value(rule, :response_template),
      conditions: fetch_value(rule, :conditions) || %{},
      requires_review: fetch_value(rule, :requires_review) || false
    }
  end

  defp normalize_action(action) when is_map(action) do
    action_name = normalize_action_name(fetch_value(action, :action))

    %{
      id:
        fetch_value(action, :id) || stable_id("#{action_name}:#{fetch_value(action, :target_id)}"),
      action: action_name,
      target_id: fetch_value(action, :target_id),
      target_author_id: fetch_value(action, :target_author_id),
      text: fetch_value(action, :text),
      rule: fetch_value(action, :rule),
      reason: fetch_value(action, :reason),
      priority: normalize_integer(fetch_value(action, :priority) || action_priority(action_name)),
      requires_review: fetch_value(action, :requires_review) || false,
      metadata: fetch_value(action, :metadata) || %{}
    }
    |> drop_nil_values()
  end

  defp rule_matches?(rule, event, opts) do
    conditions = rule.conditions

    [
      event_type_matches?(conditions, event),
      text_matches?(conditions, event),
      follower_matches?(conditions, event),
      sentiment_matches?(conditions, event),
      self_filter_matches?(conditions, event, opts),
      tag_matches?(conditions, event)
    ]
    |> Enum.all?()
  end

  defp event_type_matches?(conditions, event) do
    case fetch_value(conditions, :type) || fetch_value(conditions, :event_type) do
      nil -> true
      expected -> event.type == normalize_event_type(expected)
    end
  end

  defp text_matches?(conditions, event) do
    contains =
      List.wrap(
        fetch_value(conditions, :text_contains) || fetch_value(conditions, :contains) || []
      )

    excludes = List.wrap(fetch_value(conditions, :text_excludes) || [])
    text = String.downcase(event.text || "")

    Enum.all?(contains, &String.contains?(text, String.downcase(to_string(&1)))) and
      Enum.all?(excludes, &(not String.contains?(text, String.downcase(to_string(&1)))))
  end

  defp follower_matches?(conditions, event) do
    min_followers = normalize_integer(fetch_value(conditions, :min_followers) || 0)
    max_followers = normalize_integer(fetch_value(conditions, :max_followers))

    event.author_followers >= min_followers and
      (is_nil(max_followers) or event.author_followers <= max_followers)
  end

  defp sentiment_matches?(conditions, event) do
    case fetch_value(conditions, :sentiment) do
      nil -> true
      expected -> event.sentiment == normalize_sentiment(expected)
    end
  end

  defp self_filter_matches?(conditions, event, opts) do
    not_from_self = truthy?(fetch_value(conditions, :not_from_self))
    self_ids = opts |> Map.get(:self_author_ids, []) |> List.wrap() |> MapSet.new()

    not not_from_self or not MapSet.member?(self_ids, event.author_id)
  end

  defp tag_matches?(conditions, event) do
    required_tags = List.wrap(fetch_value(conditions, :tags) || [])
    required_tags == [] or Enum.any?(required_tags, &(&1 in event.tags))
  end

  defp build_action(rule, event) do
    text = render_template(rule.response_template, event)

    %{
      id: stable_id("#{rule.name}:#{rule.action}:#{event.id}"),
      action: rule.action,
      target_id: event.id,
      target_author_id: event.author_id,
      text: text,
      rule: rule.name,
      reason: "#{rule.name} matched #{event.type}",
      priority: rule.priority,
      requires_review: rule.requires_review or rule.action in [:direct_message, :unfollow],
      metadata: %{source_event: event}
    }
    |> drop_nil_values()
  end

  defp build_schedule_entry(item, slot) do
    %{
      id: item.id,
      action: item.action,
      text: item.text,
      campaign: item.campaign,
      tags: item.tags,
      priority: item.priority,
      status: :scheduled,
      scheduled_at: DateTime.to_iso8601(slot),
      character_count: String.length(item.text),
      warnings: item.warnings,
      metadata: item.metadata
    }
  end

  defp next_slot(start_at, interval_seconds, per_day_limit, index, day_counts) do
    candidate = DateTime.add(start_at, index * interval_seconds, :second)
    day = Date.to_iso8601(DateTime.to_date(candidate))

    if Map.get(day_counts, day, 0) < per_day_limit do
      candidate
    else
      candidate
      |> DateTime.to_date()
      |> Date.add(1)
      |> DateTime.new!(Time.new!(9, 0, 0), "Etc/UTC")
      |> next_available_day(per_day_limit, day_counts)
    end
  end

  defp next_available_day(candidate, per_day_limit, day_counts) do
    day = Date.to_iso8601(DateTime.to_date(candidate))

    if Map.get(day_counts, day, 0) < per_day_limit do
      candidate
    else
      candidate
      |> DateTime.add(24 * 60 * 60, :second)
      |> next_available_day(per_day_limit, day_counts)
    end
  end

  defp dedupe_actions(actions) do
    actions
    |> Enum.reduce({[], MapSet.new()}, fn action, {acc, seen} ->
      key = {Map.get(action, :action), Map.get(action, :target_id), Map.get(action, :text)}

      if MapSet.member?(seen, key) do
        {acc, seen}
      else
        {[action | acc], MapSet.put(seen, key)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp estimated_drain_minutes(0, _limit, _window_minutes), do: 0

  defp estimated_drain_minutes(count, limit, window_minutes) do
    windows = Float.ceil(count / limit) |> trunc()
    max(windows - 1, 0) * window_minutes
  end

  defp content_warnings(text) do
    []
    |> maybe_add_warning(String.length(text) > 280, :over_character_limit)
    |> maybe_add_warning(String.trim(text) == "", :empty_text)
    |> Enum.reverse()
  end

  defp maybe_add_warning(warnings, true, warning), do: [warning | warnings]
  defp maybe_add_warning(warnings, false, _warning), do: warnings

  defp render_template(nil, _event), do: nil

  defp render_template(template, event) do
    template
    |> to_string()
    |> String.replace("{{author_handle}}", to_string(event.author_handle || ""))
    |> String.replace("{{text}}", event.text || "")
    |> String.replace("{{event_id}}", to_string(event.id || ""))
  end

  defp normalize_event_type(type) when is_atom(type), do: type

  defp normalize_event_type(type) when is_binary(type) do
    case type |> String.downcase() |> String.replace("-", "_") do
      "mention" -> :mention
      "reply" -> :reply
      "quote" -> :quote
      "repost" -> :repost
      "follow" -> :follow
      "direct_message" -> :direct_message
      "hashtag" -> :hashtag
      _ -> :unknown
    end
  end

  defp normalize_event_type(_type), do: :unknown

  defp normalize_action_name(action) when is_atom(action), do: action

  defp normalize_action_name(action) when is_binary(action) do
    case action |> String.downcase() |> String.replace("-", "_") do
      "reply" -> :reply
      "quote" -> :quote
      "repost" -> :repost
      "retweet" -> :repost
      "like" -> :like
      "follow" -> :follow
      "direct_message" -> :direct_message
      "dm" -> :direct_message
      "unfollow" -> :unfollow
      "tweet" -> :tweet
      _ -> :reply
    end
  end

  defp normalize_action_name(_action), do: :reply

  defp normalize_sentiment(nil), do: :neutral
  defp normalize_sentiment(sentiment) when is_atom(sentiment), do: sentiment

  defp normalize_sentiment(sentiment) when is_binary(sentiment) do
    case String.downcase(sentiment) do
      "positive" -> :positive
      "negative" -> :negative
      "neutral" -> :neutral
      _ -> :neutral
    end
  end

  defp action_priority(action), do: Map.get(@action_priorities, normalize_action_name(action), 10)

  defp stable_id(value) do
    :crypto.hash(:sha256, to_string(value))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end

  defp sort_counts(counts) when is_map(counts) do
    counts
    |> Enum.sort_by(fn {key, count} -> {-count, to_string(key)} end)
    |> Enum.map(fn {key, count} -> %{value: key, count: count} end)
  end

  defp parse_datetime!(%DateTime{} = datetime), do: datetime

  defp parse_datetime!(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _ -> raise ArgumentError, "invalid ISO8601 datetime: #{value}"
    end
  end

  defp parse_datetime!(value), do: raise(ArgumentError, "invalid datetime: #{inspect(value)}")

  defp normalize_options(opts) when is_list(opts), do: Map.new(opts)
  defp normalize_options(opts) when is_map(opts), do: normalize_option_keys(opts)
  defp normalize_options(_opts), do: %{}

  defp normalize_option_keys(opts) do
    Enum.reduce(opts, %{}, fn
      {key, value}, acc when is_atom(key) -> Map.put(acc, key, value)
      {"start_at", value}, acc -> Map.put(acc, :start_at, value)
      {"interval_minutes", value}, acc -> Map.put(acc, :interval_minutes, value)
      {"per_day_limit", value}, acc -> Map.put(acc, :per_day_limit, value)
      {"timezone", value}, acc -> Map.put(acc, :timezone, value)
      {"now", value}, acc -> Map.put(acc, :now, value)
      {"per_window_limit", value}, acc -> Map.put(acc, :per_window_limit, value)
      {"window_minutes", value}, acc -> Map.put(acc, :window_minutes, value)
      {"review_required_actions", value}, acc -> Map.put(acc, :review_required_actions, value)
      {"self_author_ids", value}, acc -> Map.put(acc, :self_author_ids, value)
      {_key, _value}, acc -> acc
    end)
  end

  defp normalize_integer(nil), do: nil
  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp truthy?(value), do: value in [true, "true", 1, "1", true]

  defp reject_blank(values), do: Enum.reject(values, &(&1 in [nil, ""]))

  defp fetch_value(map, key) when is_map(map) and is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> nil
    end
  end

  defp drop_nil_values(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end
end
