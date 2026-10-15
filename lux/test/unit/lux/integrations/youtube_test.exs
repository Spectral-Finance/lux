defmodule Lux.Integrations.YouTubeTest do
  use ExUnit.Case, async: false

  alias Lux.Integrations.YouTube
  alias Lux.Prisms.YouTube.CorePrism

  setup do
    YouTube.reset_state!()
    :ok
  end

  describe "OAuth2 authentication and token refresh" do
    test "configures OAuth2 session and refreshes access token" do
      assert {:ok, session} =
               YouTube.configure_oauth2(%{
                 client_id: "lux-yt-client.apps.googleusercontent.com",
                 refresh_token: "1//refresh_token_example"
               })

      assert String.starts_with?(session.access_token, "ya29.")
      assert "https://www.googleapis.com/auth/youtube" in session.scopes

      assert {:ok, refreshed} = YouTube.refresh_access_token(expires_in: 7200)
      assert refreshed.access_token != session.access_token
    end
  end

  describe "channel, video upload/update, and playlist management" do
    test "uploads video, updates metadata, creates playlist, and tracks channel videos" do
      assert {:ok, video} =
               YouTube.upload_video(%{
                 title: "Autonomous AI Agents Live Demo",
                 description: "Deep dive into Lux multi-agent orchestration",
                 tags: ["AI", "Elixir", "Lux"],
                 privacy_status: "unlisted"
               })

      assert String.starts_with?(video.video_id, "vid_")
      assert video.privacy_status == "unlisted"

      assert {:ok, updated} =
               YouTube.update_video(video.video_id, %{
                 title: "Autonomous AI Agents Live Demo (4K)",
                 privacy_status: "public"
               })

      assert updated.privacy_status == "public"

      assert {:ok, playlist} =
               YouTube.create_playlist(%{
                 title: "Lux Engineering Streams",
                 video_ids: [video.video_id]
               })

      assert video.video_id in playlist.video_ids

      assert {:ok, channel} = YouTube.get_channel()
      assert channel.video_count == 1
    end
  end

  describe "live streaming setup, lifecycle transitions, and health monitoring" do
    test "creates stream and broadcast, binds them, transitions testing -> live -> complete, and monitors health" do
      assert {:ok, stream} =
               YouTube.create_live_stream(%{
                 title: "Primary 1080p60 Encoder",
                 quality_profile: "1080p60",
                 ingestion_type: "rtmp"
               })

      assert stream.resolution == "1080p"
      assert stream.frame_rate == "60fps"
      assert stream.health.status == :good

      assert {:ok, broadcast} =
               YouTube.create_live_broadcast(%{
                 title: "Weekly Autonomous Agent Townhall",
                 latency_preference: "ultraLow",
                 enable_dvr: true
               })

      assert broadcast.lifecycle_status == :created

      assert {:ok, bound} =
               YouTube.bind_broadcast_to_stream(broadcast.broadcast_id, stream.stream_id)

      assert bound.lifecycle_status == :ready
      assert bound.bound_stream_id == stream.stream_id

      assert {:ok, testing} =
               YouTube.transition_broadcast(broadcast.broadcast_id, :testing)

      assert testing.lifecycle_status == :testing

      assert {:ok, live} =
               YouTube.transition_broadcast(broadcast.broadcast_id, :live)

      assert live.lifecycle_status == :live
      assert live.concurrent_viewers >= 120

      assert {:ok, degraded} =
               YouTube.check_stream_health(stream.stream_id, %{
                 ingest_bitrate_kbps: 2_100,
                 dropped_frames_pct: 12.5
               })

      assert degraded.health.status == :bad
      assert degraded.health.recommended_quality_profile == "1080p30"

      assert {:ok, completed} =
               YouTube.transition_broadcast(broadcast.broadcast_id, :complete)

      assert completed.lifecycle_status == :complete
    end
  end

  describe "real-time chat interaction, moderation, and quota enforcement" do
    test "sends, polls, and moderates live chat messages and enforces daily quota" do
      {:ok, broadcast} = YouTube.create_live_broadcast(%{title: "Live Q&A"})
      chat_id = broadcast.live_chat_id

      {:ok, msg1} = YouTube.send_chat_message(chat_id, "Welcome everyone!", author: "HostBot")
      {:ok, msg2} = YouTube.send_chat_message(chat_id, "Spam link here", author: "SpamUser")

      assert {:ok, page1} = YouTube.poll_chat_messages(chat_id, page_token: 0, max_results: 10)
      assert length(page1.messages) == 2
      assert page1.next_page_token == 2

      assert {:ok, _} =
               YouTube.moderate_chat(chat_id, :delete_message, %{message_id: msg2.message_id})

      assert {:ok, page2} = YouTube.poll_chat_messages(chat_id, page_token: 0, max_results: 10)
      assert Enum.map(page2.messages, & &1.message_id) == [msg1.message_id]

      {:ok, quota} = YouTube.get_quota_status()
      assert quota.units_used > 0

      YouTube.set_quota_limit(quota.units_used + 10)
      assert {:error, :quota_exceeded} = YouTube.upload_video(%{title: "Over Quota Video"})
    end
  end

  describe "CorePrism handler" do
    test "executes YouTube workflow actions through CorePrism" do
      assert {:ok, %{status: "ok", data: stream}} =
               CorePrism.handler(
                 %{
                   action: "create_live_stream",
                   title: "Prism Stream",
                   quality_profile: "1440p60"
                 },
                 %{}
               )

      assert {:ok, %{status: "ok", data: broadcast}} =
               CorePrism.handler(
                 %{action: "create_live_broadcast", title: "Prism Broadcast"},
                 %{}
               )

      assert {:ok, %{status: "ok", data: _bound}} =
               CorePrism.handler(
                 %{
                   action: "bind_broadcast",
                   broadcast_id: broadcast.broadcast_id,
                   stream_id: stream.stream_id
                 },
                 %{}
               )

      assert {:ok, %{status: "ok", data: live}} =
               CorePrism.handler(
                 %{
                   action: "transition_broadcast",
                   broadcast_id: broadcast.broadcast_id,
                   target_state: "auto_live"
                 },
                 %{}
               )

      assert live.lifecycle_status == :live
    end
  end
end
