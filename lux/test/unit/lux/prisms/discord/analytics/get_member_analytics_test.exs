defmodule Lux.Prisms.Discord.Analytics.GetMemberAnalyticsTest do
  @moduledoc """
  Test suite for GetMemberAnalytics prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Analytics.GetMemberAnalytics
  alias Lux.Prisms.Discord.Analytics.TrackActivity

  @guild_id "123456789012345678"
  @user_id "223456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    TrackActivity.handler(%{guild_id: @guild_id, event_type: "member_join", user_id: @user_id, metadata: %{}}, @agent_ctx)
    TrackActivity.handler(%{guild_id: @guild_id, event_type: "member_join", user_id: "323456789012345678", metadata: %{}}, @agent_ctx)
    TrackActivity.handler(%{guild_id: @guild_id, event_type: "member_leave", user_id: "423456789012345678", metadata: %{}}, @agent_ctx)
    TrackActivity.handler(%{guild_id: @guild_id, event_type: "message", user_id: @user_id, metadata: %{}}, @agent_ctx)
    :ok
  end

  describe "handler/2" do
    test "retrieves member analytics" do
      assert {:ok, %{success: true, analytics: analytics}} =
               GetMemberAnalytics.handler(
                 %{
                   guild_id: @guild_id,
                   period: "week",
                   include_roles: false
                 },
                 @agent_ctx
               )

      assert analytics.new_members >= 2
      assert analytics.left_members >= 1
      assert analytics.net_growth >= 1
      assert analytics.active_members >= 1
    end
  end
end