defmodule Lux.Integrations.Twitter.Automation.AutoReplyManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Automation.AutoReplyManager

  describe "AutoReplyManager" do
    test "determines eligibility and respects cooldown" do
      tweet = %{
        author_id: "user_123",
        author: %{username: "crypto_enthusiast"},
        text: "Hey @LuxBot where can I find the docs?"
      }

      state = %{}

      assert {:ok, true, :eligible} = AutoReplyManager.should_reply?(tweet, state)

      # After updating cooldown:
      state = AutoReplyManager.update_cooldown(state, "user_123")
      assert {:ok, false, :in_cooldown} = AutoReplyManager.should_reply?(tweet, state)
    end

    test "avoids self mentions and blacklisted accounts" do
      self_tweet = %{author_id: "my_bot", text: "Announcing new features"}
      assert {:ok, false, :self_mention} =
               AutoReplyManager.should_reply?(self_tweet, %{}, %{bot_id: "my_bot"})

      blocked_tweet = %{
        author_id: "spammer_99",
        author: %{username: "spammer_account"},
        text: "Check this out"
      }

      assert {:ok, false, :blacklisted_user} =
               AutoReplyManager.should_reply?(blocked_tweet, %{}, %{
                 blacklisted_users: ["spammer_account"]
               })
    end

    test "generates contextual template reply" do
      doc_tweet = %{
        author: %{username: "dev_alice"},
        text: "Where can I read the docs for Lux?"
      }

      assert {:ok, reply} = AutoReplyManager.generate_reply(doc_tweet)
      assert String.contains?(reply, "@dev_alice")
      assert String.contains?(reply, "https://docs.lux.xyz")

      greeting_tweet = %{
        author: %{username: "bob"},
        text: "gm everyone!"
      }

      assert {:ok, greet_reply} = AutoReplyManager.generate_reply(greeting_tweet)
      assert String.contains?(greet_reply, "@bob")
      assert String.contains?(greet_reply, "reaching out")
    end
  end
end
