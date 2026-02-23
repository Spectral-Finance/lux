defmodule Lux.Prisms.Twitter.Automation.ApplyEngagementRules do
  @moduledoc """
  A prism for applying configurable engagement rules to Twitter interactions.

  Evaluates a tweet against a set of rules and determines what actions should
  be taken (like, retweet, reply, follow author, etc.) based on matching criteria.

  ## Examples

      iex> ApplyEngagementRules.handler(%{
      ...>   tweet: %{id: "123", text: "Love #Elixir!", author_id: "456", metrics: %{like_count: 50}},
      ...>   rules: [
      ...>     %{condition: %{keywords: ["elixir", "phoenix"]}, action: "like"},
      ...>     %{condition: %{min_likes: 25}, action: "retweet"}
      ...>   ]
      ...> }, %{name: "EngagementBot"})
      {:ok, %{matched_rules: [...], actions_taken: ["like", "retweet"], tweet_id: "123"}}
  """

  use Lux.Prism,
    name: "Apply Engagement Rules",
    description: "Evaluate and apply engagement rules to a tweet (like, retweet, reply)",
    input_schema: %{
      type: :object,
      properties: %{
        tweet: %{
          type: :object,
          description: "Tweet object with id, text, author_id, and metrics"
        },
        rules: %{
          type: :array,
          description: "List of engagement rules with conditions and actions",
          items: %{
            type: :object,
            properties: %{
              condition: %{
                type: :object,
                description: "Matching condition: keywords, min_likes, min_retweets, author_ids"
              },
              action: %{
                type: :string,
                enum: ["like", "retweet", "reply", "follow", "bookmark"],
                description: "Action to take when the condition matches"
              },
              reply_text: %{
                type: :string,
                description: "Reply text (required when action is 'reply')"
              }
            }
          }
        },
        dry_run: %{
          type: :boolean,
          description: "If true, evaluate rules but do not execute actions"
        }
      },
      required: ["tweet", "rules"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "ID of the evaluated tweet"},
        matched_rules: %{type: :array, description: "Rules that matched the tweet"},
        actions_taken: %{type: :array, description: "Actions that were executed"},
        dry_run: %{type: :boolean, description: "Whether this was a dry run"}
      },
      required: ["tweet_id", "matched_rules", "actions_taken"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Evaluates engagement rules against a tweet and executes matching actions.
  """
  def handler(%{tweet: tweet, rules: rules} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    dry_run = Map.get(params, :dry_run, false)
    tweet_id = tweet[:id] || tweet["id"]

    Logger.info("Agent #{agent_name} evaluating #{length(rules)} rules for tweet #{tweet_id}")

    matched_rules = Enum.filter(rules, &matches_condition?(tweet, &1))
    actions = Enum.map(matched_rules, & &1[:action] || &1["action"])

    if dry_run do
      {:ok, %{
        tweet_id: tweet_id,
        matched_rules: matched_rules,
        actions_taken: [],
        would_execute: actions,
        dry_run: true
      }}
    else
      executed = execute_actions(tweet, matched_rules)
      {:ok, %{
        tweet_id: tweet_id,
        matched_rules: matched_rules,
        actions_taken: executed,
        dry_run: false
      }}
    end
  end

  def handler(_params, _agent), do: {:error, "Missing required parameters: tweet, rules"}

  defp matches_condition?(tweet, rule) do
    condition = rule[:condition] || rule["condition"] || %{}
    text = tweet[:text] || tweet["text"] || ""
    metrics = tweet[:metrics] || tweet["metrics"] || %{}
    author_id = tweet[:author_id] || tweet["author_id"]

    keywords_match?(text, condition) and
    min_likes_match?(metrics, condition) and
    min_retweets_match?(metrics, condition) and
    author_ids_match?(author_id, condition)
  end

  defp keywords_match?(_text, condition) when not is_map_key(condition, :keywords) and not is_map_key(condition, "keywords"), do: true
  defp keywords_match?(text, condition) do
    keywords = condition[:keywords] || condition["keywords"] || []
    lower_text = String.downcase(text)
    Enum.any?(keywords, fn kw -> String.contains?(lower_text, String.downcase(kw)) end)
  end

  defp min_likes_match?(_metrics, condition) when not is_map_key(condition, :min_likes) and not is_map_key(condition, "min_likes"), do: true
  defp min_likes_match?(metrics, condition) do
    min = condition[:min_likes] || condition["min_likes"] || 0
    (metrics[:like_count] || metrics["like_count"] || 0) >= min
  end

  defp min_retweets_match?(_metrics, condition) when not is_map_key(condition, :min_retweets) and not is_map_key(condition, "min_retweets"), do: true
  defp min_retweets_match?(metrics, condition) do
    min = condition[:min_retweets] || condition["min_retweets"] || 0
    (metrics[:retweet_count] || metrics["retweet_count"] || 0) >= min
  end

  defp author_ids_match?(_author_id, condition) when not is_map_key(condition, :author_ids) and not is_map_key(condition, "author_ids"), do: true
  defp author_ids_match?(author_id, condition) do
    author_ids = condition[:author_ids] || condition["author_ids"] || []
    author_id in author_ids
  end

  defp execute_actions(tweet, matched_rules) do
    tweet_id = tweet[:id] || tweet["id"]

    Enum.flat_map(matched_rules, fn rule ->
      action = rule[:action] || rule["action"]
      case execute_action(tweet_id, action, rule) do
        {:ok, _} -> [action]
        {:error, _} -> []
      end
    end)
  end

  defp execute_action(tweet_id, "like", _rule) do
    Client.request(:post, "/tweets/#{tweet_id}/likes", %{json: %{"tweet_id" => tweet_id}})
  end

  defp execute_action(tweet_id, "retweet", _rule) do
    Client.request(:post, "/tweets/#{tweet_id}/retweets", %{json: %{"tweet_id" => tweet_id}})
  end

  defp execute_action(tweet_id, "reply", rule) do
    reply_text = rule[:reply_text] || rule["reply_text"] || "Thanks for your tweet!"
    body = %{"text" => reply_text, "reply" => %{"in_reply_to_tweet_id" => tweet_id}}
    Client.request(:post, "/tweets", %{json: body})
  end

  defp execute_action(tweet_id, "bookmark", _rule) do
    Client.request(:post, "/tweets/#{tweet_id}/bookmarks", %{json: %{"tweet_id" => tweet_id}})
  end

  defp execute_action(_tweet_id, action, _rule) do
    Logger.warning("Unknown engagement action: #{action}")
    {:error, "Unknown action: #{action}"}
  end
end
