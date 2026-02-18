defmodule Lux.Prisms.Telegram.Analytics.UserEngagementTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Prisms.Telegram.Analytics.UserEngagement
  alias Lux.Integrations.Telegram.Analytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "handler/2 - track action" do
    test "tracks user activity" do
      assert {:ok, %{tracked: true, user_id: 42}} =
               UserEngagement.handler(%{action: "track", user_id: 42}, @agent_ctx)
    end

    test "tracks user with string ID" do
      assert {:ok, %{tracked: true, user_id: "user_123"}} =
               UserEngagement.handler(%{action: "track", user_id: "user_123"}, @agent_ctx)
    end

    test "returns error when user_id missing" do
      assert {:error, "Missing required parameter: user_id"} =
               UserEngagement.handler(%{action: "track"}, @agent_ctx)
    end

    test "returns error when user_id is nil" do
      assert {:error, "Missing required parameter: user_id"} =
               UserEngagement.handler(%{action: "track", user_id: nil}, @agent_ctx)
    end
  end

  describe "handler/2 - stats action" do
    test "returns engagement statistics" do
      UserEngagement.handler(%{action: "track", user_id: 1}, @agent_ctx)
      UserEngagement.handler(%{action: "track", user_id: 2}, @agent_ctx)
      UserEngagement.handler(%{action: "track", user_id: 1}, @agent_ctx)

      assert {:ok, stats} = UserEngagement.handler(%{action: "stats"}, @agent_ctx)
      assert stats.total_unique_users == 2
      assert stats.active_users_last_hour == 2
      assert stats.active_users_last_day == 2
      assert is_list(stats.top_users)
    end

    test "returns zeroes when no users tracked" do
      assert {:ok, stats} = UserEngagement.handler(%{action: "stats"}, @agent_ctx)
      assert stats.total_unique_users == 0
      assert stats.top_users == []
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      assert {:error, "Unknown action: foo. Use 'track' or 'stats'."} =
               UserEngagement.handler(%{action: "foo"}, @agent_ctx)
    end

    test "returns error for missing action" do
      assert {:error, "Missing required parameter: action"} =
               UserEngagement.handler(%{}, @agent_ctx)
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = UserEngagement.view()
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :user_id)
    end

    test "validates output schema" do
      prism = UserEngagement.view()
      assert Map.has_key?(prism.output_schema.properties, :tracked)
      assert Map.has_key?(prism.output_schema.properties, :total_unique_users)
      assert Map.has_key?(prism.output_schema.properties, :top_users)
    end
  end
end
