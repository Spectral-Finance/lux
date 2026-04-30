defmodule Lux.Prisms.Twitter.EngagementRulesPrism do
  @moduledoc """
  A prism that manages rule-based Twitter engagement actions.

  Defines and executes engagement rules for automated actions such as
  following/unfollowing users, liking tweets, retweeting content,
  and managing follower relationships based on configurable criteria.

  ## Examples

      iex> Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
      ...>   action: "like",
      ...>   tweet_id: "12345",
      ...>   rules: [%{type: "keyword_match", keywords: ["elixir", "web3"]}]
      ...> })
      {:ok, %{action_taken: "like", reason: "keyword_match"}}
  """

  use Lux.Prism,
    name: "Engagement Rules",
    description: "Rule-based engagement system for automated Twitter actions including follow/unfollow, like, and retweet",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to evaluate or execute",
          enum: ["follow", "unfollow", "like", "retweet", "quote_tweet", "none"]
        },
        tweet_id: %{
          type: :string,
          description: "Tweet ID for the action"
        },
        user_id: %{
          type: :string,
          description: "User ID for follow/unfollow actions"
        },
        tweet_text: %{
          type: :string,
          description: "Text content of the tweet"
        },
        author_followers: %{
          type: :integer,
          description: "Follower count of the tweet author"
        },
        author_following: %{
          type: :integer,
          description: "Following count of the tweet author"
        },
        engagement_count: %{
          type: :integer,
          description: "Current engagement count on the tweet"
        },
        rules: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              type: %{type: :string},
              keywords: %{type: :array},
              min_followers: %{type: :integer},
              max_followers: %{type: :integer},
              min_engagement: %{type: :integer},
              blacklist: %{type: :array},
              whitelist: %{type: :array}
            }
          },
          description: "Rules to evaluate against"
        },
        current_following_count: %{
          type: :integer,
          description: "Current number of accounts being followed"
        },
        max_following: %{
          type: :integer,
          description: "Maximum number of accounts to follow",
          default: 5000
        },
        dry_run: %{
          type: :boolean,
          description: "If true, only evaluate without executing",
          default: true
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action_taken: %{type: :string},
        action_executed: %{type: :boolean},
        reason: %{type: :string},
        rule_matched: %{type: :string},
        score: %{type: :number},
        should_execute: %{type: :boolean},
        recommendations: %{type: :array}
      }
    }

  @doc """
  Evaluates engagement rules and determines whether to execute the action.
  """
  def run(params) do
    action = Map.get(params, :action, params["action"])
    tweet_id = Map.get(params, :tweet_id, params["tweet_id"])
    user_id = Map.get(params, :user_id, params["user_id"])
    tweet_text = Map.get(params, :tweet_text, params["tweet_text"] || "")
    author_followers = Map.get(params, :author_followers, params["author_followers"] || 0)
    author_following = Map.get(params, :author_following, params["author_following"] || 0)
    engagement_count = Map.get(params, :engagement_count, params["engagement_count"] || 0)
    rules = Map.get(params, :rules, params["rules"] || default_rules())
    current_following_count = Map.get(params, :current_following_count, params["current_following_count"] || 0)
    max_following = Map.get(params, :max_following, params["max_following"] || 5000)
    dry_run = Map.get(params, :dry_run, params["dry_run"] || true)

    # Evaluate rules
    {should_execute, reason, rule_matched, score} = evaluate_rules(%{
      action: action,
      tweet_id: tweet_id,
      user_id: user_id,
      tweet_text: tweet_text,
      author_followers: author_followers,
      author_following: author_following,
      engagement_count: engagement_count,
      rules: rules,
      current_following_count: current_following_count,
      max_following: max_following
    })

    # Generate recommendations
    recommendations = generate_recommendations(%{
      action: action,
      should_execute: should_execute,
      author_followers: author_followers,
      engagement_count: engagement_count,
      current_following_count: current_following_count,
      max_following: max_following
    })

    result = %{
      action_taken: action,
      action_executed: should_execute and not dry_run,
      reason: reason,
      rule_matched: rule_matched,
      score: score,
      should_execute: should_execute,
      recommendations: recommendations
    }

    {:ok, result}
  end

  defp evaluate_rules(params) do
    %{
      action: action,
      rules: rules,
      tweet_text: tweet_text,
      author_followers: author_followers,
      engagement_count: engagement_count,
      current_following_count: current_following_count,
      max_following: max_following
    } = params

    # Check global limits for follow actions
    if action == "follow" and current_following_count >= max_following do
      {false, "following_limit_reached", nil, 0.0}
    else
      # Evaluate each rule
      results = Enum.map(rules, &evaluate_rule(&1, params))

      # Find the first matching rule
      matching_rule = Enum.find(results, fn {should_exec, _, _, _} -> should_exec end)

      case matching_rule do
        nil ->
          # No rule matched, use default behavior
          {default_action(action, params), "no_rule_matched", nil, 0.0}
        {should_exec, reason, rule_type, score} ->
          {should_exec, reason, rule_type, score}
      end
    end
  end

  defp evaluate_rule(rule, params) do
    rule_type = Map.get(rule, :type, rule["type"])
    tweet_text = Map.get(params, :tweet_text, "")
    tweet_text_lower = String.downcase(tweet_text)
    author_followers = Map.get(params, :author_followers, 0)
    engagement_count = Map.get(params, :engagement_count, 0)

    case rule_type do
      "keyword_match" ->
        keywords = Map.get(rule, :keywords, rule["keywords"] || [])
        matched_keywords = Enum.filter(keywords, &String.contains?(tweet_text_lower, String.downcase(&1)))

        if length(matched_keywords) > 0 do
          {true, "keyword_match: #{Enum.join(matched_keywords, ", ")}", "keyword_match", length(matched_keywords) * 0.3}
        else
          {false, "no_keyword_match", "keyword_match", 0.0}
        end

      "follower_count" ->
        min_followers = Map.get(rule, :min_followers, rule["min_followers"] || 0)
        max_followers = Map.get(rule, :max_followers, rule["max_followers"] || :infinity)

        cond do
          author_followers >= min_followers and (max_followers == :infinity or author_followers <= max_followers) ->
            {true, "follower_count_within_range", "follower_count", 0.5}
          author_followers < min_followers ->
            {false, "below_min_followers", "follower_count", 0.0}
          true ->
            {false, "above_max_followers", "follower_count", 0.0}
        end

      "engagement_threshold" ->
        min_engagement = Map.get(rule, :min_engagement, rule["min_engagement"] || 0)

        if engagement_count >= min_engagement do
          {true, "engagement_threshold_met", "engagement_threshold", min(1.0, engagement_count / max(min_engagement, 1))}
        else
          {false, "below_engagement_threshold", "engagement_threshold", 0.0}
        end

      "blacklist" ->
        blacklist = Map.get(rule, :blacklist, rule["blacklist"] || [])
        blacklisted = Enum.any?(blacklist, &String.contains?(tweet_text_lower, String.downcase(&1)))

        if blacklisted do
          {false, "blacklisted_content", "blacklist", 0.0}
        else
          {true, "not_blacklisted", "blacklist", 1.0}
        end

      "whitelist" ->
        whitelist = Map.get(rule, :whitelist, rule["whitelist"] || [])
        whitelisted = Enum.any?(whitelist, &String.contains?(tweet_text_lower, String.downcase(&1)))

        if whitelisted do
          {true, "whitelisted_content", "whitelist", 1.0}
        else
          {false, "not_whitelisted", "whitelist", 0.0}
        end

      _ ->
        {false, "unknown_rule_type", rule_type, 0.0}
    end
  end

  defp default_action(action, params) do
    engagement_count = Map.get(params, :engagement_count, 0)
    author_followers = Map.get(params, :author_followers, 0)

    # Default behavior: engage if there's some engagement
    cond do
      action in ["like", "retweet"] and engagement_count > 0 -> true
      action == "follow" and author_followers > 100 -> true
      true -> false
    end
  end

  defp default_rules do
    [
      %{type: "keyword_match", keywords: ["defi", "web3", "crypto", "blockchain"]},
      %{type: "follower_count", min_followers: 10, max_followers: 100000},
      %{type: "engagement_threshold", min_engagement: 1},
      %{type: "blacklist", blacklist: ["spam", "scam", "pump", "rug"]}
    ]
  end

  defp generate_recommendations(params) do
    %{
      action: action,
      should_execute: should_execute,
      author_followers: author_followers,
      engagement_count: engagement_count,
      current_following_count: current_following_count,
      max_following: max_following
    } = params

    recommendations = []

    # Following ratio recommendation
    recommendations = if action == "follow" and current_following_count > max_following * 0.8 do
      ["Consider unfollowing inactive accounts to stay within following limits."]
    else
      recommendations
    end

    # Engagement quality recommendation
    recommendations = if engagement_count > 100 and author_followers < 1000 do
      ["High engagement from smaller account - potential micro-influencer worth engaging with."]
    else
      recommendations
    end

    # General recommendations
    recommendations = if should_execute do
      ["Action approved by engagement rules."]
    else
      ["Action blocked by engagement rules. Review rule configuration if needed."]
    end ++ recommendations

    recommendations
  end
end
