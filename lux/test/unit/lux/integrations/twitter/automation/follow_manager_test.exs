defmodule Lux.Integrations.Twitter.Automation.FollowManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Automation.FollowManager

  describe "FollowManager" do
    test "whitelists protected accounts and identifies unfollow candidates" do
      state =
        FollowManager.init_state(["founder_1", "partner_2"])
        |> FollowManager.record_follow("founder_1", ~U[2024-01-01 00:00:00Z])
        |> FollowManager.record_follow("non_reciprocal_user", ~U[2024-01-01 00:00:00Z])
        |> FollowManager.record_follow("recent_user", ~U[2024-01-20 00:00:00Z])

      current_followers = ["recent_user"]
      as_of = ~U[2024-01-15 00:00:00Z]

      # non_reciprocal_user followed on Jan 1, as_of is Jan 15 (>7 days), not in whitelist, not in current_followers
      # founder_1 is in whitelist
      # recent_user is in current_followers and was followed after as_of
      candidates =
        FollowManager.identify_unfollow_candidates(state, current_followers, 7, as_of)

      assert candidates == ["non_reciprocal_user"]
    end

    test "evaluates target user profile based on bio keywords" do
      target_user = %{
        description: "Building autonomous AI agents and web3 protocols at Lux",
        public_metrics: %{followers_count: 3500, following_count: 500}
      }

      keywords = ["ai agents", "web3", "machine learning"]

      assert {:ok, should_follow, score} =
               FollowManager.evaluate_target_user(target_user, keywords)

      assert should_follow == true
      assert score > 50.0
    end
  end
end
