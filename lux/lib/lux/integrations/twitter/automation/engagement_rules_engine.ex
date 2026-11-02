defmodule Lux.Integrations.Twitter.Automation.EngagementRulesEngine do
  @moduledoc """
  Rule-based engagement system for Twitter interactions.
  Evaluates tweets against declarative matching rules, checks daily action caps,
  and dispatches safe engagement actions (like, retweet, quote_tweet, follow).
  """

  @default_daily_caps %{
    like: 50,
    retweet: 25,
    quote_tweet: 15,
    reply: 30,
    follow: 20
  }

  @type rule :: %{
          name: String.t(),
          conditions: map(),
          actions: list(atom()),
          enabled: boolean()
        }

  @doc """
  Evaluates a tweet against a set of engagement rules, respecting daily safety caps.
  Returns matched rules and approved actions.
  """
  @spec evaluate(map(), list(rule()), map(), map()) :: {:ok, map()}
  def evaluate(tweet, rules, daily_usage \\ %{}, custom_caps \\ %{}) do
    caps = Map.merge(@default_daily_caps, custom_caps)

    matched_rules =
      rules
      |> Enum.filter(&Map.get(&1, :enabled, true))
      |> Enum.filter(&matches_conditions?(tweet, &1.conditions))

    raw_actions =
      matched_rules
      |> Enum.flat_map(&Map.get(&1, :actions, []))
      |> Enum.uniq()

    {approved_actions, throttled_actions} =
      Enum.split_with(raw_actions, fn action ->
        current_count = Map.get(daily_usage, action, 0)
        max_allowed = Map.get(caps, action, 100)
        current_count < max_allowed
      end)

    {:ok,
     %{
       matched_rules: Enum.map(matched_rules, & &1.name),
       approved_actions: approved_actions,
       throttled_actions: throttled_actions
     }}
  end

  @doc """
  Increments daily usage counter for executed action.
  """
  @spec record_action(map(), atom()) :: map()
  def record_action(daily_usage, action) when is_atom(action) do
    Map.update(daily_usage, action, 1, &(&1 + 1))
  end

  # --- Condition Matchers ---

  defp matches_conditions?(tweet, conditions) when is_map(conditions) do
    matches_keywords?(tweet, conditions) and
      matches_follower_count?(tweet, conditions) and
      matches_metrics?(tweet, conditions) and
      matches_verified?(tweet, conditions)
  end

  defp matches_keywords?(tweet, conditions) do
    text = String.downcase(Map.get(tweet, :text) || Map.get(tweet, "text") || "")

    case Map.get(conditions, :keywords_any) do
      nil ->
        true

      keywords when is_list(keywords) ->
        Enum.any?(keywords, fn kw -> String.contains?(text, String.downcase(kw)) end)
    end
  end

  defp matches_follower_count?(tweet, conditions) do
    min_followers = Map.get(conditions, :min_followers, 0)
    author = Map.get(tweet, :author) || Map.get(tweet, "author") || %{}
    followers = get_in(author, [:public_metrics, :followers_count]) || get_in(author, ["public_metrics", "followers_count"]) || 0
    followers >= min_followers
  end

  defp matches_metrics?(tweet, conditions) do
    metrics = Map.get(tweet, :public_metrics) || Map.get(tweet, "public_metrics") || %{}
    min_likes = Map.get(conditions, :min_likes, 0)
    min_retweets = Map.get(conditions, :min_retweets, 0)

    likes = Map.get(metrics, :like_count) || Map.get(metrics, "like_count", 0)
    retweets = Map.get(metrics, :retweet_count) || Map.get(metrics, "retweet_count", 0)

    likes >= min_likes and retweets >= min_retweets
  end

  defp matches_verified?(tweet, conditions) do
    case Map.get(conditions, :require_verified) do
      true ->
        author = Map.get(tweet, :author) || Map.get(tweet, "author") || %{}
        Map.get(author, :verified, false) || Map.get(author, "verified", false)

      _ ->
        true
    end
  end
end
