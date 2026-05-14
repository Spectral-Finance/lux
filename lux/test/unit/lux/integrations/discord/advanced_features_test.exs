defmodule Lux.Integrations.Discord.AdvancedFeaturesTest do
  use UnitCase, async: true

  alias Lux.Integrations.Discord.AdvancedFeatures

  @guild_id "111111111111111111"
  @channel_id "222222222222222222"

  describe "voice_channel_plan/1" do
    test "plans voice joining with audio, VAD, and music queue metadata" do
      assert {:ok, plan} =
               AdvancedFeatures.voice_channel_plan(%{
                 action: :join,
                 guild_id: @guild_id,
                 channel_id: @channel_id,
                 self_deaf: true,
                 queue: [
                   %{
                     id: "track-1",
                     title: "Intro",
                     url: "https://example.test/intro.opus",
                     duration_ms: 10_000
                   }
                 ]
               })

      assert plan.gateway.op == :voice_state_update
      assert plan.gateway.payload.self_deaf
      assert plan.audio.codec == "opus"
      assert plan.voice_activity_detection.enabled
      assert plan.queue.size == 1
      assert plan.safety.no_live_connection_opened
    end

    test "plans music playback controls" do
      assert {:ok, plan} =
               AdvancedFeatures.voice_channel_plan(%{
                 action: :play,
                 guild_id: @guild_id,
                 channel_id: @channel_id,
                 source: "https://example.test/song.opus",
                 volume: 0.5
               })

      assert plan.gateway.action == :play
      assert plan.audio.music_playback.enabled
      assert plan.audio.music_playback.volume == 0.5
    end
  end

  describe "rich_presence_plan/1" do
    test "builds Discord gateway presence payloads" do
      assert {:ok, plan} =
               AdvancedFeatures.rich_presence_plan(%{
                 status: :idle,
                 activities: [
                   %{type: :watching, name: "market alerts", details: "BTCUSDT"}
                 ]
               })

      assert plan.op == 3
      assert plan.status == "idle"
      assert [%{"type" => 3, "name" => "market alerts"}] = plan.activities
      assert plan.payload["d"]["status"] == "idle"
    end
  end

  describe "webhook_plan/1" do
    test "plans webhook creation" do
      assert {:ok, plan} =
               AdvancedFeatures.webhook_plan(%{
                 action: :create,
                 channel_id: @channel_id,
                 name: "Lux Alerts"
               })

      assert plan.request.method == :post
      assert plan.request.path == "/channels/#{@channel_id}/webhooks"
      assert plan.request.json.name == "Lux Alerts"
      assert 429 in plan.retry_policy.retry_on_status
    end

    test "plans webhook execution with custom message formatting" do
      assert {:ok, plan} =
               AdvancedFeatures.webhook_plan(%{
                 action: :execute,
                 webhook_id: "333333333333333333",
                 token: "token",
                 content: "filled",
                 username: "Lux Bot",
                 embeds: [%{title: "Trade"}]
               })

      assert plan.request.method == :post
      assert plan.request.path == "/webhooks/333333333333333333/token"
      assert plan.request.json.content == "filled"
      assert [%{title: "Trade"}] = plan.request.json.embeds
    end
  end

  describe "analytics_report/2" do
    test "summarizes activity, usage, members, and event logs" do
      events = [
        %{
          type: :message,
          subtype: :command,
          user_id: "u1",
          channel_id: "c1",
          timestamp: "2026-05-14T02:01:00Z"
        },
        %{
          type: :message,
          subtype: :reaction,
          user_id: "u2",
          channel_id: "c1",
          timestamp: "2026-05-14T02:02:00Z"
        },
        %{
          type: :voice,
          user_id: "u1",
          channel_id: "voice",
          duration_seconds: 120,
          timestamp: "2026-05-14T03:00:00Z"
        },
        %{type: :webhook, user_id: "bot", channel_id: "c2", timestamp: "2026-05-14T03:10:00Z"}
      ]

      assert {:ok, report} =
               AdvancedFeatures.analytics_report(events, %{
                 guild_id: @guild_id,
                 members: [
                   %{id: "u1", bot: false, roles: ["member"]},
                   %{id: "bot", bot: true, roles: ["bot"]}
                 ]
               })

      assert report.activity.messages == 2
      assert report.activity.by_channel["c1"] == 2
      assert report.usage.active_users == 3
      assert report.usage.commands == 1
      assert report.usage.audio_minutes == 2.0
      assert report.members.humans == 1
      assert report.members.roles["bot"] == 1
    end
  end

  describe "advanced_feature_plan/1" do
    test "combines voice, presence, webhook, and analytics plans" do
      assert {:ok, plan} =
               AdvancedFeatures.advanced_feature_plan(%{
                 voice: %{action: :join, guild_id: @guild_id, channel_id: @channel_id},
                 presence: %{status: :online, activities: [%{type: :playing, name: "Lux"}]},
                 webhook: %{action: :list, guild_id: @guild_id},
                 events: [%{type: :message, user_id: "u1", channel_id: @channel_id}],
                 analytics: %{guild_id: @guild_id}
               })

      assert plan.ready
      assert plan.voice.guild_id == @guild_id
      assert plan.rich_presence.status == "online"
      assert plan.webhook.request.path == "/guilds/#{@guild_id}/webhooks"
      assert plan.analytics.event_count == 1
    end
  end
end
