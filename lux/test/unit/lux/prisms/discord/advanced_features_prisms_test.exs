defmodule Lux.Prisms.Discord.AdvancedFeaturesPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Discord.Advanced.VoicePrism
  alias Lux.Prisms.Discord.Advanced.MusicQueuePrism
  alias Lux.Prisms.Discord.Advanced.RichPresencePrism
  alias Lux.Prisms.Discord.Advanced.WebhookPrism
  alias Lux.Prisms.Discord.Advanced.AnalyticsPrism

  describe "VoicePrism" do
    test "connects and detects vad" do
      {:ok, conn} = VoicePrism.handler(%{"action" => "connect", "guild_id" => "g1"}, %{})
      assert conn.status == "connected"

      {:ok, vad} = VoicePrism.handler(%{"action" => "detect_vad", "guild_id" => "g1", "amplitude" => 0.15}, %{})
      assert vad.status == "ok"
      assert vad.result.speaking == true
    end
  end

  describe "MusicQueuePrism" do
    test "adds track and gets queue" do
      track = %{"title" => "Cyberpunk Lo-Fi", "url" => "https://lofi.stream", "duration_seconds" => 200}
      {:ok, add_res} = MusicQueuePrism.handler(%{"action" => "add_track", "guild_id" => "g1", "track" => track}, %{})
      assert add_res.status == "queued"

      {:ok, q_res} = MusicQueuePrism.handler(%{"action" => "get_queue", "guild_id" => "g1"}, %{})
      assert q_res.status == "ok"
    end
  end

  describe "RichPresencePrism" do
    test "syncs game and custom status" do
      {:ok, sync_res} = RichPresencePrism.handler(%{"action" => "sync_game", "activity_name" => "Market Bot"}, %{})
      assert sync_res.status == "synchronized"

      {:ok, custom_res} = RichPresencePrism.handler(%{"action" => "custom_status", "text" => "Scanning DEXs"}, %{})
      assert custom_res.status == "updated"
    end
  end

  describe "WebhookPrism" do
    test "creates and triggers event webhook" do
      {:ok, create_res} = WebhookPrism.handler(%{"action" => "create_webhook", "channel_id" => "c1"}, %{})
      assert create_res.status == "created"

      {:ok, trigger_res} = WebhookPrism.handler(%{"action" => "trigger_event", "event_name" => "TEST_EVENT"}, %{})
      assert trigger_res.status == "triggered"
    end
  end

  describe "AnalyticsPrism" do
    test "logs event and retrieves server stats" do
      {:ok, log_res} = AnalyticsPrism.handler(%{"action" => "log_event", "guild_id" => "g1", "event_type" => "msg"}, %{})
      assert log_res.status == "logged"

      {:ok, stats_res} = AnalyticsPrism.handler(%{"action" => "server_stats", "guild_id" => "g1"}, %{})
      assert stats_res.status == "ok"
      assert stats_res.stats.total_events >= 1
    end
  end
end
