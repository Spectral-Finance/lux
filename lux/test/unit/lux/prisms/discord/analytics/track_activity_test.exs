defmodule Lux.Prisms.Discord.Analytics.TrackActivityTest do
  @moduledoc """
  Test suite for TrackActivity prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Analytics.TrackActivity

  @guild_id "123456789012345678"
  @user_id "223456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "successfully tracks message event" do
      assert {:ok, %{tracked: true, event_id: event_id, guild_id: @guild_id}} =
               TrackActivity.handler(
                 %{
                   guild_id: @guild_id,
                   event_type: "message",
                   user_id: @user_id,
                   channel_id: "323456789012345678",
                   metadata: %{"content" => "Hello world"}
                 },
                 @agent_ctx
               )
      
      assert is_binary(event_id)
    end

    test "tracks reaction event" do
      assert {:ok, %{tracked: true}} =
               TrackActivity.handler(
                 %{
                   guild_id: @guild_id,
                   event_type: "reaction_add",
                   user_id: @user_id,
                   metadata: %{"emoji" => "👍", "message_id" => "423456789012345678"}
                 },
                 @agent_ctx
               )
    end

    test "handles missing required fields" do
      assert {:error, "Missing or invalid guild_id"} =
               TrackActivity.handler(
                 %{
                   event_type: "message",
                   user_id: @user_id
                 },
                 @agent_ctx
               )
    end
  end
end