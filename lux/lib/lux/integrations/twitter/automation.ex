defmodule Lux.Integrations.Twitter.Automation do
  @moduledoc """
  Transport-neutral Twitter/X automation helpers.

  This module builds scheduling records, engagement-rule decisions, queue state
  transitions, content-calendar summaries, and safe action plans. API clients
  can execute the returned action plans against Twitter/X endpoints.
  """

  @valid_states [:pending, :running, :completed, :failed, :canceled]

  @doc """
  Builds a scheduled post queue item.
  """
  @spec schedule_post(String.t(), String.t(), map()) :: map()
  def schedule_post(content, scheduled_at, opts \\ %{}) when is_binary(content) and is_binary(scheduled_at) do
    %{
      id: value(opts, :id) || queue_id(:post, content, scheduled_at),
      type: :post,
      state: :pending,
      content: content,
      scheduled_at: scheduled_at,
      account_id: value(opts, :account_id),
      tags: value(opts, :tags) || [],
      metadata: value(opts, :metadata) || %{},
      created_at: value(opts, :created_at) || DateTime.utc_now()
    }
  end

  @doc """
  Builds a generic engagement queue item.
  """
  @spec enqueue_action(atom(), map(), map()) :: map()
  def enqueue_action(type, payload, opts \\ %{}) when is_atom(type) and is_map(payload) do
    %{
      id: value(opts, :id) || queue_id(type, inspect(payload), value(opts, :scheduled_at) || ""),
      type: type,
      state: :pending,
      payload: payload,
      scheduled_at: value(opts, :scheduled_at),
      priority: value(opts, :priority) || :normal,
      attempts: value(opts, :attempts) || 0,
      max_attempts: value(opts, :max_attempts) || 3,
      metadata: value(opts, :metadata) || %{}
    }
  end

  @doc """
  Transitions a queue item into a new state.
  """
  @spec transition(map(), atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def transition(item, new_state, attrs \\ %{}) when is_map(item) and new_state in @valid_states do
    {:ok,
     item
     |> Map.put(:state, new_state)
     |> Map.put(:updated_at, value(attrs, :updated_at) || DateTime.utc_now())
     |> put_optional(:result, value(attrs, :result))
     |> put_optional(:error, value(attrs, :error))}
  end

  def transition(_item, new_state, _attrs), do: {:error, "Unsupported Twitter automation state: #{new_state}"}

  @doc """
  Evaluates engagement rules against a tweet, mention, or account event.
  """
  @spec evaluate_rules(map(), [map()]) :: [map()]
  def evaluate_rules(event, rules) when is_map(event) and is_list(rules) do
    rules
    |> Enum.filter(&rule_matches?(event, &1))
    |> Enum.map(fn rule ->
      %{
        rule_id: value(rule, :id),
        action: value(rule, :action),
        reason: value(rule, :reason) || "rule matched",
        priority: value(rule, :priority) || :normal,
        payload: merge_payload(value(rule, :payload) || %{}, event)
      }
    end)
  end

  @doc """
  Builds Twitter/X API action plans for common automation operations.
  """
  @spec action_plan(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def action_plan(:create_tweet, %{text: text} = attrs) when is_binary(text) do
    payload =
      %{text: text}
      |> put_optional(:reply, reply_payload(attrs))

    {:ok, plan(:create_tweet, :post, "/2/tweets", payload, attrs)}
  end

  def action_plan(:repost, %{user_id: user_id, tweet_id: tweet_id} = attrs) do
    {:ok, plan(:repost, :post, "/2/users/#{user_id}/retweets", %{tweet_id: tweet_id}, attrs)}
  end

  def action_plan(:follow, %{user_id: user_id, target_user_id: target_user_id} = attrs) do
    {:ok, plan(:follow, :post, "/2/users/#{user_id}/following", %{target_user_id: target_user_id}, attrs)}
  end

  def action_plan(:direct_message, %{participant_id: participant_id, text: text} = attrs) when is_binary(text) do
    {:ok, plan(:direct_message, :post, "/2/dm_conversations/with/#{participant_id}/messages", %{text: text}, attrs)}
  end

  def action_plan(action, _attrs), do: {:error, "Unsupported Twitter automation action: #{action}"}

  @doc """
  Summarizes scheduled content by calendar day and status.
  """
  @spec calendar_summary([map()]) :: [map()]
  def calendar_summary(items) when is_list(items) do
    items
    |> Enum.group_by(&calendar_day(value(&1, :scheduled_at)))
    |> Enum.map(fn {day, day_items} ->
      %{
        day: day,
        total: length(day_items),
        pending: count_state(day_items, :pending),
        completed: count_state(day_items, :completed),
        failed: count_state(day_items, :failed),
        tags: day_items |> Enum.flat_map(&(value(&1, :tags) || [])) |> Enum.uniq() |> Enum.sort()
      }
    end)
    |> Enum.sort_by(& &1.day)
  end

  defp rule_matches?(event, rule) do
    conditions = value(rule, :conditions) || %{}

    Enum.all?(conditions, fn {metric, expected} ->
      compare(metric_value(event, metric), expected)
    end)
  end

  defp compare(value, %{operator: operator, value: expected}), do: compare(value, operator, expected)
  defp compare(value, %{"operator" => operator, "value" => expected}), do: compare(value, operator, expected)
  defp compare(value, expected), do: value == expected

  defp compare(value, :>, expected), do: value > expected
  defp compare(value, :>=, expected), do: value >= expected
  defp compare(value, :<, expected), do: value < expected
  defp compare(value, :<=, expected), do: value <= expected
  defp compare(value, :contains, expected) when is_binary(value), do: String.contains?(String.downcase(value), String.downcase(expected))
  defp compare(value, ">", expected), do: value > expected
  defp compare(value, ">=", expected), do: value >= expected
  defp compare(value, "<", expected), do: value < expected
  defp compare(value, "<=", expected), do: value <= expected
  defp compare(value, "contains", expected) when is_binary(value), do: String.contains?(String.downcase(value), String.downcase(expected))
  defp compare(value, _operator, expected), do: value == expected

  defp merge_payload(payload, event) do
    payload
    |> Enum.reduce(%{}, fn {key, payload_value}, acc ->
      Map.put(acc, normalize_key(key), resolve_payload_value(payload_value, event))
    end)
  end

  defp resolve_payload_value({:event, key}, event), do: value(event, key)
  defp resolve_payload_value(value, _event), do: value

  defp reply_payload(attrs) do
    case value(attrs, :reply_to_tweet_id) do
      nil -> nil
      tweet_id -> %{in_reply_to_tweet_id: tweet_id}
    end
  end

  defp plan(action, method, endpoint, payload, attrs) do
    %{
      action: action,
      method: method,
      endpoint: endpoint,
      payload: payload,
      idempotency_key: value(attrs, :idempotency_key)
    }
  end

  defp calendar_day(nil), do: nil
  defp calendar_day(<<day::binary-size(10), _rest::binary>>), do: day
  defp calendar_day(day), do: day

  defp count_state(items, state), do: Enum.count(items, &(value(&1, :state) == state))

  defp metric_value(event, metric), do: value(event, metric)

  defp queue_id(type, seed, scheduled_at) do
    "twitter-#{type}-#{:erlang.phash2({seed, scheduled_at})}"
  end

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
