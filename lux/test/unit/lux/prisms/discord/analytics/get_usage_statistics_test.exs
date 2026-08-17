defmodule Lux.Prisms.Discord.Analytics.GetUsageStatisticsTest do
  @moduledoc """
  Test suite for GetUsageStatistics prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Analytics.GetUsageStatistics
  alias Lux.Prisms.Discord.Analytics.TrackActivity

  @guild_id "123456789012345678"
  @user_id "223456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    # Add some test events
    TrackActivity.handler(%{guild_id: @guild_id, event_type: "message", user_id: @user_id, channel_id: "323456789012345678", metadata: %{}}, @agent_ctx)
    TrackActivity.handler(%{guild_id: @guild_id, event_type: "message", user_id: @user_id, channel_id: "323456789012345678", metadata: %{}}, @agent_ctx)
    TrackActivity.handler(%{guild_id: @guild_id, event_type: "reaction_add", user_id: @user_id, metadata: %{"emoji" => "👍"}}, @agent_ctx)
    TrackActivity.handler(%{guild_id: @guild_id, event_type: "voice_join", user_id: @user_id, channel_id: "423456789012345678"}, @agent_ctx)
    :ok
  end

  describe "handler/2" do
    test "retrieves usage statistics for day period" do
      assert {:ok, %{success: true, statistics: stats}} =
               GetUsageStatistics.handler(
                 %{
                   guild_id: @guild_id,
                   period: "day",
                   metrics: ["messages", "reactions", "voice_minutes", "active_users"]
                 },
                 @agent_ctx
               )

      assert stats.total_messages >= 2
      assert stats.total_reactions >= 1
      assert stats.total_voice_minutes >= 5
      assert stats.active_users >= 1
    end

    test "returns empty stats for unknown guild" do
      assert {:ok, %{success: true, statistics: stats}} =
               GetUsageStatistics.handler(
                 %{
                   guild_id: "999999999999999999",
                   period: "day"
                 },
                 @agent_ctx
               )

      assert stats.total_messages == 0
    end
  end
end