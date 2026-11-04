defmodule Lux.Discord.VoiceAndPresenceTest do
  use UnitCase, async: true

  alias Lux.Discord.Voice
  alias Lux.Discord.Presence
  alias Lux.Discord.MusicQueue
  alias Lux.Discord.Analytics
  alias Lux.Discord.Webhook

  describe "Lux.Discord.Voice" do
    setup do
      Voice.reset!()
      :ok
    end

    test "connects and disconnects voice channel" do
      guild_id = "111222"
      channel_id = "333444"

      assert {:ok, session} = Voice.connect_channel(guild_id, channel_id)
      assert session.status == :connected
      assert session.guild_id == guild_id

      assert {:ok, state} = Voice.get_connection_state(guild_id)
      assert state.channel_id == channel_id

      assert :ok = Voice.disconnect_channel(guild_id)
      assert {:error, :not_connected} = Voice.get_connection_state(guild_id)
    end

    test "streams audio when connected" do
      guild_id = "111222"
      Voice.connect_channel(guild_id, "333444")

      assert {:ok, stream} = Voice.stream_audio(guild_id, "https://audio.example.com/test.mp3")
      assert stream.status == :streaming
    end

    test "detects voice activity based on amplitude" do
      assert {:ok, true, level} = Voice.detect_voice_activity(0.12, 0.05)
      assert level > 0.05

      assert {:ok, false, _} = Voice.detect_voice_activity(0.01, 0.05)
    end
  end

  describe "Lux.Discord.Presence" do
    test "updates bot presence with game status" do
      assert {:ok, presence} =
               Presence.update_presence(%{
                 status: :online,
                 activity_name: "Trading Sim",
                 activity_type: :game
               })

      assert presence.status == :online
      assert hd(presence.activities).name == "Trading Sim"
    end

    test "sets custom status" do
      assert {:ok, presence} = Presence.set_custom_status("Autonomous building", "⚡")
      assert hd(presence.activities).state == "Autonomous building"
    end
  end

  describe "Lux.Discord.MusicQueue" do
    test "manages track queue, skip, and pause" do
      guild_id = "queue_guild"
      MusicQueue.clear(guild_id)

      track1 = %{title: "Track 1", url: "url1", duration_seconds: 120, requested_by: "alice"}
      track2 = %{title: "Track 2", url: "url2", duration_seconds: 180, requested_by: "bob"}

      {:ok, _} = MusicQueue.add_track(guild_id, track1)
      {:ok, _} = MusicQueue.add_track(guild_id, track2)

      state = MusicQueue.get_queue(guild_id)
      assert length(state.queue) == 2

      {:ok, next} = MusicQueue.skip(guild_id)
      assert next.title == "Track 1"

      MusicQueue.pause(guild_id)
      assert MusicQueue.get_queue(guild_id).is_playing == false

      MusicQueue.resume(guild_id)
      assert MusicQueue.get_queue(guild_id).is_playing == true
    end
  end

  describe "Lux.Discord.Analytics" do
    setup do
      Analytics.reset!()
      :ok
    end

    test "logs events and aggregates stats" do
      guild_id = "analytics_guild"
      Analytics.log_event("command_run", guild_id, "user_1")
      Analytics.log_event("voice_join", guild_id, "user_2")

      stats = Analytics.get_server_stats(guild_id)
      assert stats.total_events == 2
      assert stats.active_users_count == 2
    end
  end

  describe "Lux.Discord.Webhook" do
    test "creates and sends webhook payload" do
      assert {:ok, wh} = Webhook.create_webhook("ch_1", "Test Webhook")
      assert is_binary(wh.url)

      assert {:ok, res} = Webhook.send_webhook_message(wh.url, "Hello via webhook")
      assert res.delivered == true
    end
  end
end
