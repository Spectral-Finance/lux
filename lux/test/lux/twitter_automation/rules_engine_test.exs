defmodule Lux.TwitterAutomation.RulesEngineTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAutomation.RulesEngine
  alias Lux.TwitterAutomation.Storage

  setup do
    {:ok, _pid} = start_supervised(RulesEngine)
    Storage.clear_all()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  describe "add_rule/1" do
    test "adds a new rule" do
      rule = %{
        type: :auto_reply,
        enabled: true,
        conditions: %{
          keywords: ["test"],
          min_followers: 100
        },
        actions: %{
          reply_template: "Thanks for the {{text}}"
        },
        rate_limit: %{max_per_hour: 5}
      }

      assert {:ok, id} = RulesEngine.add_rule(rule)
      assert is_binary(id)

      # Verify the rule is stored in Storage
      {:ok, stored_rule} = Storage.get_rule(id)
      assert stored_rule.type == :auto_reply
      assert stored_rule.enabled == true
      assert stored_rule.conditions.keywords == ["test"]
    end

    test "generates ID if not provided" do
      rule = %{
        type: :auto_like,
        enabled: false
      }

      assert {:ok, id} = RulesEngine.add_rule(rule)
      assert is_binary(id)

      {:ok, stored_rule} = Storage.get_rule(id)
      assert stored_rule.id == id
    end

    test "disables rule by default for safety" do
      rule = %{
        type: :auto_reply,
        conditions: %{
          keywords: ["test"]
        },
        actions: %{
          reply_template: "Thanks for the test"
        }
      }

      assert {:ok, id} = RulesEngine.add_rule(rule)

      {:ok, stored_rule} = Storage.get_rule(id)
      assert stored_rule.enabled == false
    end
  end

  describe "update_rule/2" do
    test "updates an existing rule" do
      rule = %{
        type: :auto_reply,
        enabled: false,
        conditions: %{keywords: ["test"]},
        actions: %{reply_template: "Old template"}
      }

      {:ok, id} = RulesEngine.add_rule(rule)

      # Update the rule
      changes = %{
        enabled: true,
        actions: %{reply_template: "New template"},
        rate_limit: %{max_per_hour: 10}
      }

      assert :ok = RulesEngine.update_rule(id, changes)

      # Verify the update
      {:ok, updated_rule} = Storage.get_rule(id)
      assert updated_rule.enabled == true
      assert updated_rule.actions.reply_template == "New template"
      assert updated_rule.rate_limit.max_per_hour == 10
    end

    test "returns error for non-existent rule" do
      assert {:error, :not_found} = RulesEngine.update_rule("nonexistent", %{enabled: true})
    end
  end

  describe "delete_rule/1" do
    test "deletes an existing rule" do
      rule = %{
        type: :auto_reply,
        enabled: true
      }

      {:ok, id} = RulesEngine.add_rule(rule)

      # Verify it exists
      {:ok, _rule} = Storage.get_rule(id)

      # Delete it
      assert :ok = RulesEngine.delete_rule(id)

      # Verify it's gone
      assert {:error, :not_found} = Storage.get_rule(id)
    end
  end

  describe "enable_rule/1 and disable_rule/1" do
    test "enables a rule" do
      rule = %{
        type: :auto_reply,
        enabled: false
      }

      {:ok, id} = RulesEngine.add_rule(rule)

      # Verify it starts disabled
      {:ok, rule} = Storage.get_rule(id)
      assert rule.enabled == false

      # Enable it
      assert :ok = RulesEngine.enable_rule(id)

      # Verify it's enabled
      {:ok, enabled_rule} = Storage.get_rule(id)
      assert enabled_rule.enabled == true
    end

    test "disables a rule" do
      rule = %{
        type: :auto_reply,
        enabled: true
      }

      {:ok, id} = RulesEngine.add_rule(rule)

      # Verify it starts enabled
      {:ok, rule} = Storage.get_rule(id)
      assert rule.enabled == true

      # Disable it
      assert :ok = RulesEngine.disable_rule(id)

      # Verify it's disabled
      {:ok, disabled_rule} = Storage.get_rule(id)
      assert disabled_rule.enabled == false
    end

    test "returns error for non-existent rule" do
      assert {:error, :not_found} = RulesEngine.enable_rule("nonexistent")
      assert {:error, :not_found} = RulesEngine.disable_rule("nonexistent")
    end
  end

  describe "list_rules/1" do
    test "lists all rules" do
      rule1 = %{type: :auto_reply, enabled: true, conditions: %{keywords: ["test1"]}}
      rule2 = %{type: :auto_like, enabled: false, conditions: %{keywords: ["test2"]}}

      {:ok, id1} = RulesEngine.add_rule(rule1)
      {:ok, id2} = RulesEngine.add_rule(rule2)

      {:ok, rules} = RulesEngine.list_rules()
      assert length(rules) == 2
      rule_ids = Enum.map(rules, & &1.id)
      assert id1 in rule_ids
      assert id2 in rule_ids
    end

    test "lists only enabled rules" do
      rule1 = %{type: :auto_reply, enabled: true, conditions: %{keywords: ["test1"]}}
      rule2 = %{type: :auto_like, enabled: false, conditions: %{keywords: ["test2"]}}

      {:ok, id1} = RulesEngine.add_rule(rule1)
      {:ok, id2} = RulesEngine.add_rule(rule2)

      {:ok, enabled_rules} = RulesEngine.list_rules(%{enabled: true})
      assert length(enabled_rules) == 1
      assert hd(enabled_rules).id == id1
    end

    test "lists only disabled rules" do
      rule1 = %{type: :auto_reply, enabled: true, conditions: %{keywords: ["test1"]}}
      rule2 = %{type: :auto_like, enabled: false, conditions: %{keywords: ["test2"]}}

      {:ok, id1} = RulesEngine.add_rule(rule1)
      {:ok, id2} = RulesEngine.add_rule(rule2)

      {:ok, disabled_rules} = RulesEngine.list_rules(%{enabled: false})
      assert length(disabled_rules) == 1
      assert hd(disabled_rules).id == id2
    end
  end

  describe "rule matching" do
    test "matches rule with keyword condition" do
      rule = %{
        type: :auto_reply,
        enabled: true,
        conditions: %{keywords: ["elixir", "phoenix"]},
        actions: %{reply_template: "Thanks for mentioning Elixir!"}
      }

      {:ok, id} = RulesEngine.add_rule(rule)
      RulesEngine.enable_rule(id)

      # Tweet that matches
      tweet = %{
        id: "tweet123",
        text: "I love using Elixir for web development",
        author: %{username: "testuser", followers_count: 200}
      }

      assert {:match, 1} = RulesEngine.evaluate_tweet(tweet)

      # Tweet that doesn't match
      non_matching_tweet = %{
        id: "tweet456",
        text: "I love using Python for data science",
        author: %{username: "testuser", followers_count: 200}
      }

      assert :no_match = RulesEngine.evaluate_tweet(non_matching_tweet)
    end

    test "matches rule with exclude keyword condition" do
      rule = %{
        type: :auto_reply,
        enabled: true,
        conditions: %{
          keywords: ["test"],
          exclude_keywords: ["spam", "advertisement"]
        },
        actions: %{reply_template: "Thanks for the test"}
      }

      {:ok, id} = RulesEngine.add_rule(rule)
      RulesEngine.enable_rule(id)

      # Tweet that matches (contains 'test' but not excluded words)
      tweet = %{
        id: "tweet123",
        text: "This is a test tweet",
        author: %{username: "testuser", followers_count: 200}
      }

      assert {:match, 1} = RulesEngine.evaluate_tweet(tweet)

      # Tweet that doesn't match (contains 'test' but also excluded word)
      excluded_tweet = %{
        id: "tweet456",
        text: "This is a test advertisement",
        author: %{username: "testuser", followers_count: 200}
      }

      assert :no_match = RulesEngine.evaluate_tweet(excluded_tweet)
    end

    test "matches rule with minimum follower condition" do
      rule = %{
        type: :auto_reply,
        enabled: true,
        conditions: %{
          keywords: ["hello"],
          min_followers: 100
        },
        actions: %{reply_template: "Welcome!"}
      }

      {:ok, id} = RulesEngine.add_rule(rule)
      RulesEngine.enable_rule(id)

      # Tweet from user with enough followers
      tweet = %{
        id: "tweet123",
        text: "Hello everyone!",
        author: %{username: "popular_user", followers_count: 150}
      }

      assert {:match, 1} = RulesEngine.evaluate_tweet(tweet)

      # Tweet from user with too few followers
      low_follower_tweet = %{
        id: "tweet456",
        text: "Hello everyone!",
        author: %{username: "new_user", followers_count: 50}
      }

      assert :no_match = RulesEngine.evaluate_tweet(low_follower_tweet)
    end
  end

  describe "rule execution" do
    test "executes auto_reply rule" do
      rule = %{
        type: :auto_reply,
        enabled: true,
        conditions: %{keywords: ["hello"]},
        actions: %{reply_template: "Hello {{username}}, thanks for the tweet!"}
      }

      {:ok, id} = RulesEngine.add_rule(rule)
      RulesEngine.enable_rule(id)

      tweet = %{
        id: "tweet123",
        text: "Hello everyone!",
        author: %{username: "testuser", followers_count: 200}
      }

      assert {:match, 1} = RulesEngine.evaluate_tweet(tweet)
    end

    test "handles multiple matching rules" do
      rule1 = %{
        type: :auto_reply,
        enabled: true,
        conditions: %{keywords: ["elixir"]},
        actions: %{reply_template: "Nice Elixir post!"}
      }

      rule2 = %{
        type: :auto_reply,
        enabled: true,
        conditions: %{keywords: ["web"]},
        actions: %{reply_template: "Web development is great!"}
      }

      {:ok, id1} = RulesEngine.add_rule(rule1)
      {:ok, id2} = RulesEngine.add_rule(rule2)
      RulesEngine.enable_rule(id1)
      RulesEngine.enable_rule(id2)

      # Tweet that matches both rules
      tweet = %{
        id: "tweet123",
        text: "Building web apps with Elixir is great",
        author: %{username: "testuser", followers_count: 200}
      }

      assert {:match, 2} = RulesEngine.evaluate_tweet(tweet)
    end
  end

  describe "rate limiting" do
    test "respects rate limits per rule" do
      rule = %{
        type: :auto_reply,
        enabled: true,
        conditions: %{keywords: ["test"]},
        actions: %{reply_template: "Thanks for the test"},
        rate_limit: %{max_per_hour: 1}
      }

      {:ok, id} = RulesEngine.add_rule(rule)
      RulesEngine.enable_rule(id)

      tweet1 = %{
        id: "tweet1",
        text: "This is a test tweet",
        author: %{username: "user1", followers_count: 200}
      }

      tweet2 = %{
        id: "tweet2",
        text: "Another test tweet",
        author: %{username: "user2", followers_count: 200}
      }

      # First tweet should match
      assert {:match, 1} = RulesEngine.evaluate_tweet(tweet1)

      # Second tweet should not match due to rate limit
      assert :no_match = RulesEngine.evaluate_tweet(tweet2)
    end
  end

  describe "cleanup" do
    test "clears all rule data" do
      rule = %{
        type: :auto_reply,
        enabled: true,
        conditions: %{keywords: ["test"]}
      }

      {:ok, _id} = RulesEngine.add_rule(rule)
      assert length(RulesEngine.list_rules() |> elem(1)) == 1

      Storage.clear_all()
      assert length(RulesEngine.list_rules() |> elem(1)) == 0
    end
  end
end