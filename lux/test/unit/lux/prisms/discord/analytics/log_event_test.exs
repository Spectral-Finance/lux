defmodule Lux.Prisms.Discord.Analytics.LogEventTest do
  @moduledoc """
  Test suite for LogEvent prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Analytics.LogEvent

  @guild_id "123456789012345678"
  @user_id "223456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "successfully logs info event" do
      assert {:ok, %{logged: true, event_id: event_id, guild_id: @guild_id}} =
               LogEvent.handler(
                 %{
                   guild_id: @guild_id,
                   event_type: "moderation",
                   severity: "info",
                   message: "User warned",
                   user_id: @user_id,
                   tags: ["warning", "automod"]
                 },
                 @agent_ctx
               )
      
      assert is_binary(event_id)
    end

    test "logs critical event with full metadata" do
      assert {:ok, %{logged: true}} =
               LogEvent.handler(
                 %{
                   guild_id: @guild_id,
                   event_type: "security",
                   severity: "critical",
                   message: "Raid detected",
                   user_id: @user_id,
                   channel_id: "323456789012345678",
                   metadata: %{"raid_score" => 95, "joined_users" => 50},
                   tags: ["raid", "security", "automod"]
                 },
                 @agent_ctx
               )
    end

    test "handles missing required fields" do
      assert {:error, "Missing or invalid guild_id"} =
               LogEvent.handler(
                 %{
                   event_type: "moderation",
                   message: "Test"
                 },
                 @agent_ctx
               )
    end
  end
end