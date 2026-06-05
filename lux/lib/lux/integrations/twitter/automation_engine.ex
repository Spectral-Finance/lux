defmodule Lux.Integrations.Twitter.AutomationEngine do
  @moduledoc """
  Builds deterministic Twitter automation plans for scheduling posts, applying
  engagement rules, and managing a rate-limited action queue.

  The engine does not call Twitter/X APIs directly. It produces an auditable plan
  that agents can review or pass to a separate delivery integration.
  """

  @spam_terms [
    "airdrop",
    "giveaway",
    "free money",
    "guaranteed",
    "click here",
    "dm me"
  ]

  @default_surface_limits %{
    "tweet_write" => %{
      max_actions_per_hour: 8,
      access_tier: "write",
      backoff_seconds: 900,
      requires_review: false
    },
    "engagement_write" => %{
      max_actions_per_hour: 16,
      access_tier: "write",
      backoff_seconds: 600,
      requires_review: false
    },
    "relationship_write" => %{
      max_actions_per_hour: 4,
      access_tier: "write",
      backoff_seconds: 1800,
      requires_review: true
    },
    "dm_write" => %{
      max_actions_per_hour: 2,
      access_tier: "elevated",
      backoff_seconds: 3600,
      requires_review: true
    },
    "manual_review" => %{
      max_actions_per_hour: 6,
      access_tier: "operator",
      backoff_seconds: 0,
      requires_review: true
    }
  }

  @default_policy %{
    max_actions_per_hour: 12,
    min_spacing_seconds: 300,
    quiet_hours: nil,
    duplicate_window_minutes: 240,
    surface_limits: @default_surface_limits
  }

  @type plan_result :: %{
          scheduled_posts: list(map()),
          engagement_actions: list(map()),
          queue: list(map()),
          content_calendar: list(map()),
          moderation: list(map()),
          performance: map()
        }

  @doc """
  Builds an automation plan from calendar items, mentions, rules, and queue policy.
  """
  @spec plan(map()) :: {:ok, plan_result()} | {:error, String.t()}
  def plan(input) when is_map(input) do
    with {:ok, now} <- parse_datetime(value(input, :now)) do
      policy = normalize_policy(value(input, :queue_policy, %{}))
      calendar_items = value(input, :content_calendar, [])
      mentions = value(input, :mentions, value(input, :inbox, []))
      rules = value(input, :rules, [])

      scheduled_posts = schedule_posts(calendar_items, now, policy)
      engagement_actions = build_engagement_actions(mentions, rules, now)
      queue = build_queue(scheduled_posts, engagement_actions, now, policy)
      moderation = build_moderation(scheduled_posts, engagement_actions)

      {:ok,
       %{
         scheduled_posts: scheduled_posts,
         engagement_actions: engagement_actions,
         queue: queue,
         content_calendar: Enum.map(scheduled_posts, &content_calendar_entry/1),
         moderation: moderation,
         performance: performance(queue, moderation, policy)
       }}
    end
  end

  def plan(_input), do: {:error, "Expected a map of automation inputs"}

  defp schedule_posts(items, now, policy) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> normalize_post(item, index, now, policy) end)
  end

  defp schedule_posts(_items, _now, _policy), do: []

  defp normalize_post(item, index, now, policy) when is_map(item) do
    text = value(item, :text, "") |> to_string()
    id = value(item, :id, "content-#{index + 1}") |> to_string()
    scheduled_for = value(item, :scheduled_for)
    scheduled_at = parse_optional_datetime(scheduled_for, DateTime.add(now, index * 3600, :second))
    shifted_at = shift_out_of_quiet_hours(scheduled_at, policy)

    base = %{
      id: id,
      text: text,
      campaign: value(item, :campaign),
      tags: listify(value(item, :tags, [])),
      priority: int_value(value(item, :priority, 50), 50),
      scheduled_at: DateTime.to_iso8601(shifted_at)
    }

    cond do
      String.trim(text) == "" ->
        Map.merge(base, %{status: "rejected", reason: "empty_content"})

      String.length(text) > 280 ->
        Map.merge(base, %{status: "rejected", reason: "exceeds_280_characters"})

      true ->
        Map.merge(base, %{status: "scheduled", reason: "ready"})
    end
  end

  defp normalize_post(_item, index, now, policy) do
    normalize_post(%{id: "content-#{index + 1}", text: ""}, index, now, policy)
  end

  defp build_engagement_actions(mentions, rules, now) when is_list(mentions) and is_list(rules) do
    mentions
    |> Enum.with_index()
    |> Enum.flat_map(fn {mention, index} ->
      mention = normalize_mention(mention, index, now)

      rules
      |> Enum.with_index()
      |> Enum.flat_map(fn {rule, rule_index} ->
        rule = normalize_rule(rule, rule_index)

        if rule_matches?(rule, mention) do
          [engagement_action(rule, mention)]
        else
          []
        end
      end)
    end)
  end

  defp build_engagement_actions(_mentions, _rules, _now), do: []

  defp normalize_mention(mention, index, now) when is_map(mention) do
    %{
      id: value(mention, :id, "mention-#{index + 1}") |> to_string(),
      author: value(mention, :author, "unknown") |> to_string(),
      text: value(mention, :text, "") |> to_string(),
      followers: int_value(value(mention, :followers, 0), 0),
      received_at:
        parse_optional_datetime(value(mention, :received_at), DateTime.add(now, index * 60, :second))
    }
  end

  defp normalize_mention(_mention, index, now) do
    normalize_mention(%{id: "mention-#{index + 1}"}, index, now)
  end

  defp normalize_rule(rule, index) when is_map(rule) do
    type = value(rule, :type, "engage_keyword") |> to_string()

    %{
      id: value(rule, :id, "rule-#{index + 1}") |> to_string(),
      type: type,
      action_type: action_type(type),
      keywords: listify(value(rule, :keywords, [])),
      reply_template: value(rule, :reply_template, "Thanks for sharing this with us."),
      min_followers: int_value(value(rule, :min_followers, 0), 0),
      priority: int_value(value(rule, :priority, 50), 50)
    }
  end

  defp normalize_rule(_rule, index), do: normalize_rule(%{id: "rule-#{index + 1}"}, index)

  defp rule_matches?(rule, mention) do
    meets_followers? = mention.followers >= rule.min_followers
    matches_keyword? = rule.keywords == [] or contains_any?(mention.text, rule.keywords)

    meets_followers? and matches_keyword?
  end

  defp engagement_action(rule, mention) do
    action = rule.action_type
    status = engagement_status(action, mention.text)
    priority = min(100, rule.priority + min(20, div(mention.followers, 1000)))

    %{
      id: "engagement-#{mention.id}-#{rule.id}",
      type: action,
      surface: surface_for_action(action),
      target_id: mention.id,
      target_author: mention.author,
      text: action_text(action, rule, mention),
      reason: action_reason(action, rule, mention),
      priority: priority,
      received_at: DateTime.to_iso8601(mention.received_at),
      status: status
    }
  end

  defp engagement_status("dm", _text), do: "needs_review"
  defp engagement_status(_action, text), do: if(spam_risk?(text), do: "needs_review", else: "queued")

  defp action_type("auto_reply"), do: "reply"
  defp action_type("reply"), do: "reply"
  defp action_type("engage_keyword"), do: "like"
  defp action_type("like"), do: "like"
  defp action_type("follow_candidate"), do: "follow"
  defp action_type("follow"), do: "follow"
  defp action_type("repost"), do: "repost"
  defp action_type("retweet"), do: "repost"
  defp action_type("dm_sequence"), do: "dm"
  defp action_type(_type), do: "review"

  defp surface_for_action("reply"), do: "tweet_write"
  defp surface_for_action("post"), do: "tweet_write"
  defp surface_for_action("like"), do: "engagement_write"
  defp surface_for_action("repost"), do: "engagement_write"
  defp surface_for_action("follow"), do: "relationship_write"
  defp surface_for_action("dm"), do: "dm_write"
  defp surface_for_action(_action), do: "manual_review"

  defp action_text("reply", rule, mention) do
    rule.reply_template
    |> to_string()
    |> String.replace("{{author}}", mention.author)
  end

  defp action_text("dm", rule, mention), do: action_text("reply", rule, mention)
  defp action_text(_action, _rule, _mention), do: nil

  defp action_reason("reply", rule, mention) do
    "Matched #{inspect(rule.keywords)} in mention #{mention.id}; prepared reply."
  end

  defp action_reason("follow", rule, mention) do
    "Author has #{mention.followers} followers and matched #{inspect(rule.keywords)}."
  end

  defp action_reason(action, rule, mention) do
    "Rule #{rule.id} created #{action} action for mention #{mention.id}."
  end

  defp build_queue(posts, actions, now, policy) do
    posts
    |> Enum.flat_map(&post_candidate/1)
    |> Kernel.++(Enum.flat_map(actions, &action_candidate(&1, now)))
    |> Enum.sort(&candidate_before?/2)
    |> assign_queue(policy)
  end

  defp candidate_before?(left, right) do
    cond do
      left.priority != right.priority ->
        left.priority > right.priority

      DateTime.compare(left.earliest_at, right.earliest_at) != :eq ->
        DateTime.compare(left.earliest_at, right.earliest_at) == :lt

      true ->
        left.id <= right.id
    end
  end

  defp post_candidate(%{status: "scheduled"} = post) do
    {:ok, scheduled_at, _offset} = DateTime.from_iso8601(post.scheduled_at)

    [
      %{
        id: "post-#{post.id}",
        action: "post",
        surface: "tweet_write",
        source_id: post.id,
        earliest_at: scheduled_at,
        priority: post.priority,
        payload: %{text: post.text, tags: post.tags, campaign: post.campaign}
      }
    ]
  end

  defp post_candidate(_post), do: []

  defp action_candidate(%{status: "queued"} = action, now) do
    earliest_at = parse_optional_datetime(action.received_at, now)

    [
      %{
        id: action.id,
        action: action.type,
        surface: action.surface,
        source_id: action.target_id,
        earliest_at: earliest_at,
        priority: action.priority,
        payload: %{target_author: action.target_author, text: action.text, reason: action.reason}
      }
    ]
  end

  defp action_candidate(_action, _now), do: []

  defp assign_queue(candidates, policy) do
    {_last_run_at, _counts, queue} =
      Enum.reduce(candidates, {nil, %{}, []}, fn candidate, {last_run_at, counts, queue} ->
        base_run_at =
          case last_run_at do
            nil -> candidate.earliest_at
            last -> later(candidate.earliest_at, DateTime.add(last, policy.min_spacing_seconds, :second))
          end

        run_at = reserve_slot(base_run_at, counts, policy, candidate.surface)
        bucket = hour_bucket(run_at)
        surface_bucket = "#{candidate.surface}:#{bucket}"
        surface_policy = surface_policy(policy, candidate.surface)

        counts =
          counts
          |> Map.update({:global, bucket}, 1, &(&1 + 1))
          |> Map.update({candidate.surface, bucket}, 1, &(&1 + 1))

        item = %{
          id: candidate.id,
          action: candidate.action,
          surface: candidate.surface,
          source_id: candidate.source_id,
          run_at: DateTime.to_iso8601(run_at),
          status: "queued",
          priority: candidate.priority,
          rate_limit_bucket: bucket,
          surface_rate_limit_bucket: surface_bucket,
          access_tier: surface_policy.access_tier,
          backoff_seconds: surface_policy.backoff_seconds,
          requires_review: surface_policy.requires_review,
          requires_live_adapter: true,
          dedupe_key: dedupe_key(candidate),
          payload: candidate.payload
        }

        {run_at, counts, [item | queue]}
      end)

    Enum.reverse(queue)
  end

  defp reserve_slot(run_at, counts, policy, surface, attempts \\ 0) do
    run_at = shift_out_of_quiet_hours(run_at, policy)
    bucket = hour_bucket(run_at)
    surface_policy = surface_policy(policy, surface)

    cond do
      attempts > 48 ->
        run_at

      Map.get(counts, {:global, bucket}, 0) < policy.max_actions_per_hour and
          Map.get(counts, {surface, bucket}, 0) < surface_policy.max_actions_per_hour ->
        run_at

      true ->
        run_at
        |> next_hour()
        |> reserve_slot(counts, policy, surface, attempts + 1)
    end
  end

  defp build_moderation(posts, actions) do
    post_flags =
      posts
      |> Enum.reject(&(&1.status == "scheduled"))
      |> Enum.map(fn post ->
        %{source_id: post.id, source: "content_calendar", status: post.status, reason: post.reason}
      end)

    action_flags =
      actions
      |> Enum.reject(&(&1.status == "queued"))
      |> Enum.map(fn action ->
        %{source_id: action.id, source: "engagement_action", status: action.status, reason: action.reason}
      end)

    post_flags ++ action_flags
  end

  defp content_calendar_entry(post) do
    Map.take(post, [:id, :campaign, :tags, :scheduled_at, :status, :reason])
  end

  defp performance(queue, moderation, policy) do
    %{
      queue_depth: length(queue),
      moderation_count: length(moderation),
      hourly_buckets: Enum.frequencies_by(queue, & &1.rate_limit_bucket),
      surface_buckets: Enum.frequencies_by(queue, & &1.surface_rate_limit_bucket),
      max_actions_per_hour: policy.max_actions_per_hour,
      min_spacing_seconds: policy.min_spacing_seconds
    }
  end

  defp normalize_policy(policy) when is_map(policy) do
    %{
      max_actions_per_hour: int_value(value(policy, :max_actions_per_hour, 12), 12),
      min_spacing_seconds: int_value(value(policy, :min_spacing_seconds, 300), 300),
      quiet_hours: normalize_quiet_hours(value(policy, :quiet_hours)),
      duplicate_window_minutes: int_value(value(policy, :duplicate_window_minutes, 240), 240),
      surface_limits: normalize_surface_limits(value(policy, :surface_limits, %{}))
    }
  end

  defp normalize_policy(_policy), do: @default_policy

  defp normalize_surface_limits(overrides) when is_map(overrides) do
    Map.new(@default_surface_limits, fn {surface, defaults} ->
      override = Map.get(overrides, surface) || Map.get(overrides, String.to_atom(surface)) || %{}
      {surface, Map.merge(defaults, normalize_surface_limit(override))}
    end)
  end

  defp normalize_surface_limits(_overrides), do: @default_surface_limits

  defp normalize_surface_limit(limit) when is_map(limit) do
    %{
      max_actions_per_hour: int_value(value(limit, :max_actions_per_hour), nil),
      access_tier: value(limit, :access_tier),
      backoff_seconds: int_value(value(limit, :backoff_seconds), nil),
      requires_review: bool_value(value(limit, :requires_review), nil)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp normalize_surface_limit(_limit), do: %{}

  defp surface_policy(policy, surface) do
    Map.get(policy.surface_limits, surface, @default_surface_limits["manual_review"])
  end

  defp normalize_quiet_hours(nil), do: nil

  defp normalize_quiet_hours(hours) when is_map(hours) do
    start_hour = int_value(value(hours, :start_hour, value(hours, :start, 22)), 22)
    end_hour = int_value(value(hours, :end_hour, value(hours, :end, 7)), 7)

    %{start_hour: clamp_hour(start_hour), end_hour: clamp_hour(end_hour)}
  end

  defp normalize_quiet_hours(_hours), do: nil

  defp shift_out_of_quiet_hours(datetime, %{quiet_hours: nil}), do: datetime

  defp shift_out_of_quiet_hours(datetime, %{quiet_hours: %{start_hour: start_hour, end_hour: end_hour}}) do
    if quiet_hour?(datetime.hour, start_hour, end_hour) do
      seconds =
        seconds_until_allowed_hour(datetime.hour, datetime.minute, datetime.second, start_hour, end_hour)

      DateTime.add(datetime, seconds, :second)
    else
      datetime
    end
  end

  defp quiet_hour?(hour, start_hour, end_hour) when start_hour < end_hour do
    hour >= start_hour and hour < end_hour
  end

  defp quiet_hour?(hour, start_hour, end_hour) when start_hour > end_hour do
    hour >= start_hour or hour < end_hour
  end

  defp quiet_hour?(_hour, _start_hour, _end_hour), do: false

  defp seconds_until_allowed_hour(hour, minute, second, start_hour, end_hour) do
    hours_to_end =
      cond do
        start_hour < end_hour ->
          end_hour - hour

        hour >= start_hour ->
          24 - hour + end_hour

        true ->
          end_hour - hour
      end

    hours_to_end * 3600 - minute * 60 - second
  end

  defp contains_any?(text, keywords) do
    downcased_text = String.downcase(to_string(text))

    Enum.any?(keywords, fn keyword ->
      String.contains?(downcased_text, String.downcase(to_string(keyword)))
    end)
  end

  defp spam_risk?(text), do: contains_any?(text, @spam_terms)

  defp later(left, right) do
    case DateTime.compare(left, right) do
      :gt -> left
      _ -> right
    end
  end

  defp next_hour(datetime) do
    seconds = 3600 - datetime.minute * 60 - datetime.second
    DateTime.add(datetime, seconds, :second)
  end

  defp hour_bucket(datetime) do
    "#{datetime.year}-#{pad(datetime.month)}-#{pad(datetime.day)}T#{pad(datetime.hour)}"
  end

  defp dedupe_key(candidate) do
    source = "#{candidate.action}:#{candidate.source_id}:#{candidate.id}"

    :crypto.hash(:sha256, source)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp parse_optional_datetime(nil, fallback), do: fallback

  defp parse_optional_datetime(value, fallback) do
    case parse_datetime(value) do
      {:ok, datetime} -> datetime
      {:error, _reason} -> fallback
    end
  end

  defp parse_datetime(nil), do: {:ok, DateTime.utc_now()}
  defp parse_datetime(%DateTime{} = datetime), do: {:ok, datetime}

  defp parse_datetime(%NaiveDateTime{} = datetime) do
    DateTime.from_naive(datetime, "Etc/UTC")
  end

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        {:ok, datetime}

      {:error, _reason} ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, datetime} -> DateTime.from_naive(datetime, "Etc/UTC")
          {:error, _reason} -> {:error, "Invalid ISO8601 datetime: #{value}"}
        end
    end
  end

  defp parse_datetime(value), do: {:error, "Invalid datetime value: #{inspect(value)}"}

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp value(_map, _key, default), do: default

  defp listify(nil), do: []
  defp listify(value) when is_list(value), do: value
  defp listify(value), do: [value]

  defp int_value(value, _default) when is_integer(value), do: value

  defp int_value(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> default
    end
  end

  defp int_value(_value, default), do: default

  defp bool_value(value, _default) when is_boolean(value), do: value
  defp bool_value("true", _default), do: true
  defp bool_value("false", _default), do: false
  defp bool_value(_value, default), do: default

  defp clamp_hour(hour) when hour < 0, do: 0
  defp clamp_hour(hour) when hour > 23, do: 23
  defp clamp_hour(hour), do: hour

  defp pad(value) when value < 10, do: "0#{value}"
  defp pad(value), do: to_string(value)
end
