defmodule Lux.Prisms.Twitter.EngagementRules do
  @moduledoc """
  Rule-based engagement system for automated Twitter interactions.

  Features:
  - Define rules based on keywords, user attributes, engagement thresholds
  - Actions: like, retweet, reply, follow, bookmark
  - Rate limiting per action type
  - Rule priority and conditions
  """

  use GenServer

  defstruct [:rules, :action_counts, :rate_limits]

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def add_rule(pid \\ __MODULE__, rule) do
    GenServer.call(pid, {:add_rule, rule})
  end

  def remove_rule(pid \\ __MODULE__, rule_id) do
    GenServer.call(pid, {:remove_rule, rule_id})
  end

  def evaluate(pid \\ __MODULE__, tweet) do
    GenServer.call(pid, {:evaluate, tweet})
  end

  def list_rules(pid \\ __MODULE__) do
    GenServer.call(pid, :list_rules)
  end

  def get_action_counts(pid \\ __MODULE__) do
    GenServer.call(pid, :get_action_counts)
  end

  def set_rate_limit(pid \\ __MODULE__, action, limit_per_hour) do
    GenServer.call(pid, {:set_rate_limit, action, limit_per_hour})
  end

  # Server

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{
      rules: [],
      action_counts: %{},
      rate_limits: %{like: 50, retweet: 25, reply: 30, follow: 20}
    }}
  end

  @impl true
  def handle_call({:add_rule, rule}, _from, state) do
    id = rule[:id] || generate_id()
    entry = %{
      id: id,
      name: rule[:name] || "Rule #{id}",
      conditions: rule[:conditions] || [],
      actions: rule[:actions] || [],
      priority: rule[:priority] || 0,
      enabled: rule[:enabled] != false,
      created_at: DateTime.utc_now()
    }
    rules = [entry | state.rules] |> Enum.sort_by(& &1.priority, :desc)
    {:reply, {:ok, entry}, %{state | rules: rules}}
  end

  @impl true
  def handle_call({:remove_rule, rule_id}, _from, state) do
    rules = Enum.reject(state.rules, &(&1.id == rule_id))
    {:reply, :ok, %{state | rules: rules}}
  end

  @impl true
  def handle_call({:evaluate, tweet}, _from, state) do
    matching_rules = state.rules
    |> Enum.filter(& &1.enabled)
    |> Enum.filter(&matches_conditions?(&1.conditions, tweet))

    # Collect all actions, check rate limits
    actions = matching_rules
    |> Enum.flat_map(& &1.actions)
    |> Enum.uniq()
    |> Enum.filter(&within_rate_limit?(&1, state))

    # Update action counts
    new_counts = Enum.reduce(actions, state.action_counts, fn action, acc ->
      Map.update(acc, action, 1, &(&1 + 1))
    end)

    result = %{
      matched_rules: Enum.map(matching_rules, & &1.id),
      actions: actions,
      tweet_id: tweet[:id]
    }

    {:reply, {:ok, result}, %{state | action_counts: new_counts}}
  end

  @impl true
  def handle_call(:list_rules, _from, state) do
    {:reply, {:ok, state.rules}, state}
  end

  @impl true
  def handle_call(:get_action_counts, _from, state) do
    {:reply, {:ok, state.action_counts}, state}
  end

  @impl true
  def handle_call({:set_rate_limit, action, limit}, _from, state) do
    limits = Map.put(state.rate_limits, action, limit)
    {:reply, :ok, %{state | rate_limits: limits}}
  end

  # Condition matching

  defp matches_conditions?(conditions, tweet) do
    Enum.all?(conditions, &matches_condition?(&1, tweet))
  end

  defp matches_condition?({:keyword, keywords}, tweet) when is_list(keywords) do
    text = String.downcase(tweet[:text] || "")
    Enum.any?(keywords, &String.contains?(text, String.downcase(&1)))
  end

  defp matches_condition?({:min_followers, min}, tweet) do
    (tweet[:author_followers] || 0) >= min
  end

  defp matches_condition?({:min_likes, min}, tweet) do
    (tweet[:like_count] || 0) >= min
  end

  defp matches_condition?({:min_retweets, min}, tweet) do
    (tweet[:retweet_count] || 0) >= min
  end

  defp matches_condition?({:is_reply, val}, tweet) do
    (tweet[:is_reply] || false) == val
  end

  defp matches_condition?({:has_media, val}, tweet) do
    has = (tweet[:media] || []) != []
    has == val
  end

  defp matches_condition?({:language, lang}, tweet) do
    (tweet[:lang] || "en") == lang
  end

  defp matches_condition?(_, _), do: true

  defp within_rate_limit?(action, state) do
    count = Map.get(state.action_counts, action, 0)
    limit = Map.get(state.rate_limits, action, 100)
    count < limit
  end

  defp generate_id, do: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
end
