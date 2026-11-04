defmodule Lux.Prisms.Discord.AdvancedDiscordFeaturesTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.Discord.Voice.VoiceChannelManager
  alias Lux.Prisms.Discord.Presence.RichPresenceManager
  alias Lux.Prisms.Discord.Webhooks.WebhookManager
  alias Lux.Lenses.Discord.Analytics.ServerAnalyticsLens

  describe "VoiceChannelManager (#56)" do
    test "joins voice channel, streams Opus audio, configures VAD, and manages playback queue" do
      guild_id = "999888777666555444"

      assert {:ok, join_res} =
               VoiceChannelManager.handler(
                 %{action: "join", guild_id: guild_id, channel_id: "111222333444555666"},
                 %{}
               )

      assert join_res.status == "connected"
      assert join_res.voice_state.connected == true

      assert {:ok, stream_res} =
               VoiceChannelManager.handler(
                 %{
                   action: "stream_audio",
                   guild_id: guild_id,
                   encoding: "opus",
                   bitrate_kbps: 96,
                   audio_source: "https://cdn.example.com/stream.opus"
                 },
                 %{}
               )

      assert stream_res.status == "streaming"
      assert stream_res.voice_state.bitrate_kbps == 96

      assert {:ok, vad_res} =
               VoiceChannelManager.handler(
                 %{action: "configure_vad", guild_id: guild_id, vad_threshold_db: -35.0, input_level_db: -28.0},
                 %{}
               )

      assert vad_res.voice_state.speaking_detected == true

      track1 = %{title: "Synthwave Intro", url: "https://example.com/1.mp3", duration_sec: 180}
      track2 = %{title: "Cyberpunk Finale", url: "https://example.com/2.mp3", duration_sec: 240}

      assert {:ok, q1} = VoiceChannelManager.handler(%{action: "enqueue_track", guild_id: guild_id, track: track1}, %{})
      assert {:ok, q2} = VoiceChannelManager.handler(%{action: "enqueue_track", guild_id: guild_id, track: track2}, %{})
      assert length(q2.queue) == 2
      assert q1.voice_state.playing.title == "Synthwave Intro"

      assert {:ok, skip_res} = VoiceChannelManager.handler(%{action: "skip_track", guild_id: guild_id}, %{})
      assert length(skip_res.queue) == 1
      assert skip_res.voice_state.playing.title == "Cyberpunk Finale"
    end
  end

  describe "RichPresenceManager (#56)" do
    test "updates custom status, activity, game sync, and rich presence" do
      agent_id = "agent_discord_01"

      assert {:ok, s_res} =
               RichPresenceManager.handler(
                 %{action: "set_status", agent_id: agent_id, status: "dnd", custom_text: "Auditing Smart Contracts"},
                 %{}
               )

      assert s_res.presence.status == "dnd"
      assert s_res.presence.custom_text == "Auditing Smart Contracts"

      assert {:ok, a_res} =
               RichPresenceManager.handler(
                 %{action: "set_activity", agent_id: agent_id, activity_type: "streaming", activity_name: "Lux Live"},
                 %{}
               )

      assert a_res.presence.activity.type == 1

      assert {:ok, g_res} =
               RichPresenceManager.handler(
                 %{action: "sync_game", agent_id: agent_id, game_title: "On-Chain Arena"},
                 %{}
               )

      assert g_res.presence.game.synchronized == true

      assert {:ok, rp_res} =
               RichPresenceManager.handler(
                 %{
                   action: "update_rich_presence",
                   agent_id: agent_id,
                   details: "Solving Bounties",
                   state_text: "Active Queue",
                   party_current: 2,
                   party_max: 5
                 },
                 %{}
               )

      assert rp_res.presence.rich_presence.party == %{current: 2, max: 5}
    end
  end

  describe "WebhookManager (#56)" do
    test "creates webhook, sends custom formatted message with retry handling, and triggers events" do
      assert {:ok, created} =
               WebhookManager.handler(
                 %{
                   action: "create",
                   channel_id: "123456789012345678",
                   name: "Lux Alert Hook",
                   subscribed_events: ["depeg_alert", "governance_vote"]
                 },
                 %{}
               )

      wh_id = created.webhook.id

      assert {:ok, sent} =
               WebhookManager.handler(
                 %{
                   action: "send_message",
                   webhook_id: wh_id,
                   content: "Protocol alert triggered",
                   embeds: [%{title: "Alert", color: 16711680}],
                   max_retries: 3,
                   simulate_transient_failures: 2
                 },
                 %{}
               )

      assert sent.status == "delivered"
      assert sent.delivery.attempts == 3

      assert {:error, %{reason: :max_retries_exceeded}} =
               WebhookManager.handler(
                 %{
                   action: "send_message",
                   webhook_id: wh_id,
                   content: "Should fail",
                   max_retries: 2,
                   simulate_transient_failures: 3
                 },
                 %{}
               )

      assert {:ok, trig} =
               WebhookManager.handler(
                 %{action: "trigger_event", event_type: "depeg_alert", event_payload: %{pool: "USDC/USDT"}},
                 %{}
               )

      assert trig.delivery.triggered_count >= 1
    end
  end

  describe "ServerAnalyticsLens (#56)" do
    test "records guild events and aggregates usage statistics and member analytics" do
      guild_id = "777666555444333222"
      ServerAnalyticsLens.clear_analytics(guild_id)

      ServerAnalyticsLens.record_event(guild_id, %{type: :message_sent, member_id: "m1"})
      ServerAnalyticsLens.record_event(guild_id, %{type: :message_sent, member_id: "m1"})
      ServerAnalyticsLens.record_event(guild_id, %{type: :voice_join, member_id: "m2"})

      report = ServerAnalyticsLens.get_analytics(guild_id)
      assert report.usage_statistics.total_events == 3
      assert report.usage_statistics.events_by_type[:message_sent] == 2
      assert report.member_analytics.active_members == 2
      assert report.member_analytics.avg_events_per_member == 1.5
    end
  end
end
