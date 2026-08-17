defmodule Lux.Prisms.Discord.Voice.PlayMusicTest do
  @moduledoc """
  Test suite for PlayMusic prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Voice.PlayMusic

  @guild_id "123456789012345678"
  @channel_id "223456789012345678"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "adds track to queue" do
      assert {:ok, %{success: true, guild_id: @guild_id, channel_id: @channel_id, queue: queue}} =
               PlayMusic.handler(
                 %{
                   guild_id: @guild_id,
                   channel_id: @channel_id,
                   query: "test song",
                   action: "play"
                 },
                 @agent_ctx
               )
      
      assert length(queue) == 1
      assert hd(queue).title == "Track: test song"
    end

    test "pauses playback" do
      PlayMusic.handler(%{guild_id: @guild_id, channel_id: @channel_id, query: "song1", action: "play"}, @agent_ctx)
      
      assert {:ok, %{success: true, guild_id: @guild_id}} =
               PlayMusic.handler(%{guild_id: @guild_id, channel_id: @channel_id, action: "pause"}, @agent_ctx)
    end

    test "skips track" do
      PlayMusic.handler(%{guild_id: @guild_id, channel_id: @channel_id, query: "song1", action: "play"}, @agent_ctx)
      PlayMusic.handler(%{guild_id: @guild_id, channel_id: @channel_id, query: "song2", action: "play"}, @agent_ctx)
      
      assert {:ok, %{success: true, guild_id: @guild_id, queue: queue}} =
               PlayMusic.handler(%{guild_id: @guild_id, channel_id: @channel_id, action: "skip"}, @agent_ctx)
      
      assert length(queue) == 1
    end
  end
end