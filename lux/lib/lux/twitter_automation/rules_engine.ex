defmodule Lux.TwitterAutomation.RulesEngine do
  @moduledoc """
  Rule-based engagement automation for Twitter.

  Supports:
  - Auto-reply based on keywords, hashtags, mentions
  - Auto-like/retweet based on conditions
  - Conditional actions based on follower count, verified status, etc.
  - Rate limiting per rule
  """

  use GenServer
  require Logger

  alias Lux.TwitterAutomation.{Storage, QueueManager}

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Add a new rule"
  def add_rule(rule) do
    GenServer.call(__MODULE__, {:add_rule, rule})
  end

  @doc "Update an existing rule"
  def update_rule(id, changes) do
    GenServer.call(__MODULE__, {:update_rule, id, changes})
  end

  @doc "Delete a rule"
  def delete_rule(id) do
    GenServer.call(__MODULE__, {:delete_rule, id})
  end

  @doc "Enable a rule"
  def enable_rule(id) do
    GenServer.call(__MODULE__, {:enable_rule, id})
  end

  @doc "Disable a rule"
  def disable_rule(id) do
    GenServer.call(__MODULE__, {:disable_rule, id})
  end

  @doc "Evaluate a tweet against all active rules"
  def evaluate_tweet(tweet_data) do
    GenServer.call(__MODULE__, {:evaluate_tweet, tweet_data})
  end

  @doc "List all rules"
  def list_rules(opts \\ %{}) do
    GenServer.call(__MODULE__, {:list_rules, opts})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{rule_executions: %{}}}  # Track rule execution counts
  end

  @impl true
  def handle_call({:add_rule, rule}, _from, state) do
    validated_rule = %{
      id: rule[:id] || generate_id(),
      type: rule[:type] || :auto_reply,
      enabled: rule[:enabled] || false,  # Disabled by default for safety
      conditions: rule[:conditions] || %{},
      actions: rule[:actions] || %{},
      rate_limit: rule[:rate_limit] || %{max_per_hour: 10},
      created_at: DateTime.utc_now(),
      execution_count: 0
    }

    Storage.store_rule(validated_rule)
    Logger.info("Added rule #{validated_rule.id} (type: #{validated_rule.type})")

    {:reply, {:ok, validated_rule.id}, state}
  end

  @impl true
  def handle_call({:update_rule, id, changes}, _from, state) do
    case Storage.get_rule(id) do
      {:ok, rule} ->
        updated_rule = Map.merge(rule, Map.new(changes))
        Storage.store_rule(updated_rule)
        Logger.info("Updated rule #{id}")
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:delete_rule, id}, _from, state) do
    Storage.delete_rule(id)
    Logger.info("Deleted rule #{id}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:enable_rule, id}, _from, state) do
    case Storage.get_rule(id) do
      {:ok, rule} ->
        Storage.store_rule(%{rule | enabled: true})
        Logger.info("Enabled rule #{id}")
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:disable_rule, id}, _from, state) do
    case Storage.get_rule(id) do
      {:ok, rule} ->
        Storage.store_rule(%{rule | enabled: false})
        Logger.info("Disabled rule #{id}")
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:evaluate_tweet, tweet_data}, _from, state) do
    {:ok, rules} = Storage.get_enabled_rules()

    matching_rules =
      rules
      |> Enum.filter(&rule_matches?(tweet_data, &1))
      |> Enum.filter(&can_execute_rule?(&1, state))

    # Execute matching rules
    new_state =
      Enum.reduce(matching_rules, state, fn rule, acc_state ->
        execute_rule(rule, tweet_data)
        track_rule_execution(rule, acc_state)
      end)

    match_count = length(matching_rules)
    result = if match_count > 0, do: {:match, match_count}, else: :no_match

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:list_rules, opts}, _from, state) do
    result =
      case opts[:enabled] do
        true -> Storage.get_enabled_rules()
        false ->
          {:ok, all_rules} = Storage.get_all_rules()
          {:ok, Enum.filter(all_rules, &(!&1.enabled))}
        _ -> Storage.get_all_rules()
      end

    {:reply, result, state}
  end

  ## Private Functions

  defp rule_matches?(tweet, rule) do
    conditions = rule.conditions

    Enum.all?([
      check_keywords(tweet, conditions[:keywords]),
      check_exclude_keywords(tweet, conditions[:exclude_keywords]),
      check_from_users(tweet, conditions[:from_users]),
      check_min_followers(tweet, conditions[:min_followers]),
      check_hashtags(tweet, conditions[:hashtags])
    ])
  end

  defp check_keywords(_tweet, nil), do: true
  defp check_keywords(tweet, keywords) do
    text = (tweet[:text] || "") |> String.downcase()
    Enum.any?(keywords, fn keyword ->
      String.contains?(text, String.downcase(keyword))
    end)
  end

  defp check_exclude_keywords(_tweet, nil), do: true
  defp check_exclude_keywords(tweet, keywords) do
    text = (tweet[:text] || "") |> String.downcase()
    not Enum.any?(keywords, fn keyword ->
      String.contains?(text, String.downcase(keyword))
    end)
  end

  defp check_from_users(_tweet, nil), do: true
  defp check_from_users(tweet, users) do
    author_id = tweet[:author_id]
    author_id in users
  end

  defp check_min_followers(_tweet, nil), do: true
  defp check_min_followers(tweet, min_count) do
    follower_count = get_in(tweet, [:author, :followers_count]) || 0
    follower_count >= min_count
  end

  defp check_hashtags(_tweet, nil), do: true
  defp check_hashtags(tweet, required_hashtags) do
    tweet_hashtags = get_in(tweet, [:entities, :hashtags]) || []
    hashtag_texts = Enum.map(tweet_hashtags, & &1[:tag])

    Enum.any?(required_hashtags, fn tag ->
      tag in hashtag_texts
    end)
  end

  defp can_execute_rule?(rule, state) do
    rate_limit = rule.rate_limit
    max_per_hour = rate_limit[:max_per_hour] || 10

    executions = Map.get(state.rule_executions, rule.id, [])
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

    recent_executions =
      Enum.filter(executions, fn timestamp ->
        DateTime.compare(timestamp, one_hour_ago) == :gt
      end)

    length(recent_executions) < max_per_hour
  end

  defp execute_rule(rule, tweet) do
    Logger.info("Executing rule #{rule.id} (type: #{rule.type}) for tweet #{tweet[:id]}")

    case rule.type do
      :auto_reply ->
        template = rule.actions[:reply_template]
        reply_text = interpolate_template(template, tweet)
        QueueManager.enqueue(:create_tweet, %{
          text: reply_text,
          reply: %{in_reply_to_tweet_id: tweet[:id]}
        }, :normal)

      :auto_like ->
        # Note: Twitter API v2 doesn't support liking via API in free tier
        Logger.warn("Auto-like not supported in current Twitter API tier")

      :auto_retweet ->
        # Note: Twitter API v2 retweet endpoint
        Logger.warn("Auto-retweet requires additional lens implementation")

      :auto_quote ->
        template = rule.actions[:quote_template]
        quote_text = interpolate_template(template, tweet)
        QueueManager.enqueue(:create_tweet, %{
          text: quote_text,
          quote_tweet_id: tweet[:id]
        }, :normal)

      _ ->
        Logger.warn("Unknown rule type: #{rule.type}")
    end
  end

  defp track_rule_execution(rule, state) do
    executions = Map.get(state.rule_executions, rule.id, [])
    new_executions = [DateTime.utc_now() | executions]

    # Keep only last 24 hours of executions
    cutoff = DateTime.add(DateTime.utc_now(), -24 * 3600, :second)
    recent_executions = Enum.filter(new_executions, fn ts ->
      DateTime.compare(ts, cutoff) == :gt
    end)

    put_in(state, [:rule_executions, rule.id], recent_executions)
  end

  defp interpolate_template(template, tweet) do
    template
    |> String.replace("{{username}}", tweet[:author][:username] || "user")
    |> String.replace("{{tweet_id}}", tweet[:id] || "")
    |> String.replace("{{text}}", tweet[:text] || "")
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
