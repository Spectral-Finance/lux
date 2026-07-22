defmodule Lux.Prisms.YouTube.PrismsTest do
  @moduledoc """
  Unit tests for the YouTube integration Prisms.
  """
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.CreatePlaylist
  alias Lux.Prisms.YouTube.UpdateVideo
  alias Lux.Prisms.YouTube.StartLiveBroadcast
  alias Lux.Integrations.YouTube.Client, as: YouTubeClient

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "CreatePlaylist" do
    test "successfully creates a playlist" do
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/playlists"
        assert conn.params["part"] == "snippet,status"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json_body = Jason.decode!(body)
        assert json_body["snippet"]["title"] == "My Awesome Playlist"
        assert json_body["snippet"]["description"] == "A description"
        assert json_body["status"]["privacyStatus"] == "public"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "PL12345",
          "snippet" => %{
            "title" => "My Awesome Playlist"
          },
          "status" => %{
            "privacyStatus" => "public"
          }
        }))
      end)

      assert {:ok, %{
        created: true,
        playlist_id: "PL12345",
        title: "My Awesome Playlist",
        privacy_status: "public"
      }} = CreatePlaylist.handler(%{
        title: "My Awesome Playlist",
        description: "A description",
        privacy_status: "public"
      }, %{name: "TestAgent"})
    end

    test "handles client errors when creating a playlist" do
      Req.Test.expect(YouTubeClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{
            "message" => "Quota Exceeded"
          }
        }))
      end)

      assert {:error, {403, "Quota Exceeded"}} = CreatePlaylist.handler(%{
        title: "My Playlist"
      }, %{name: "TestAgent"})
    end
  end

  describe "UpdateVideo" do
    test "successfully updates a video's metadata" do
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/youtube/v3/videos"
        assert conn.params["part"] == "snippet,status"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json_body = Jason.decode!(body)
        assert json_body["id"] == "vid_123"
        assert json_body["snippet"]["title"] == "New Title"
        assert json_body["snippet"]["description"] == "New description"
        assert json_body["snippet"]["tags"] == ["elixir", "programming"]
        assert json_body["status"]["privacyStatus"] == "private"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "vid_123",
          "snippet" => %{
            "title" => "New Title"
          }
        }))
      end)

      assert {:ok, %{
        updated: true,
        video_id: "vid_123",
        title: "New Title"
      }} = UpdateVideo.handler(%{
        video_id: "vid_123",
        title: "New Title",
        description: "New description",
        tags: ["elixir", "programming"],
        privacy_status: "private"
      }, %{name: "TestAgent"})
    end

    test "handles client errors when updating a video" do
      Req.Test.expect(YouTubeClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "error" => %{
            "message" => "Video not found"
          }
        }))
      end)

      assert {:error, {404, "Video not found"}} = UpdateVideo.handler(%{
        video_id: "nonexistent",
        title: "New Title"
      }, %{name: "TestAgent"})
    end
  end

  describe "StartLiveBroadcast" do
    test "successfully creates a live broadcast and binds a live stream" do
      # 1. Expect liveBroadcasts POST
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts"
        assert conn.params["part"] == "snippet,status,contentDetails"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json_body = Jason.decode!(body)
        assert json_body["snippet"]["title"] == "My Stream"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "broadcast_123",
          "snippet" => %{
            "title" => "My Stream"
          },
          "status" => %{
            "lifeCycleStatus" => "ready",
            "privacyStatus" => "private"
          }
        }))
      end)

      # 2. Expect liveStreams POST
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveStreams"
        assert conn.params["part"] == "snippet,cdn,status"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json_body = Jason.decode!(body)
        assert json_body["snippet"]["title"] == "My Stream - Stream"
        assert json_body["cdn"]["resolution"] == "720p"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "stream_456",
          "cdn" => %{
            "ingestionInfo" => %{
              "ingestionAddress" => "rtmp://a.rtmp.youtube.com/live2",
              "streamName" => "stream_key_xyz"
            }
          }
        }))
      end)

      # 3. Expect liveBroadcasts/bind POST
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveBroadcasts/bind"
        assert conn.params["id"] == "broadcast_123"
        assert conn.params["streamId"] == "stream_456"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "broadcast_123"
        }))
      end)

      assert {:ok, %{
        created: true,
        broadcast_id: "broadcast_123",
        title: "My Stream",
        life_cycle_status: "ready",
        privacy_status: "private",
        stream_id: "stream_456",
        ingestion_address: "rtmp://a.rtmp.youtube.com/live2",
        stream_name: "stream_key_xyz"
      }} = StartLiveBroadcast.handler(%{
        title: "My Stream",
        scheduled_start_time: "2024-12-01T20:00:00Z",
        resolution: "720p"
      }, %{name: "TestAgent"})
    end

    test "handles client errors when creating a broadcast" do
      Req.Test.expect(YouTubeClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => %{
            "message" => "Invalid start time"
          }
        }))
      end)

      assert {:error, {400, "Invalid start time"}} = StartLiveBroadcast.handler(%{
        title: "My Stream",
        scheduled_start_time: "past"
      }, %{name: "TestAgent"})
    end

    test "propagates error when liveBroadcasts/bind fails" do
      # 1. Expect liveBroadcasts POST success
      Req.Test.expect(YouTubeClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "broadcast_123",
          "snippet" => %{"title" => "My Stream"},
          "status" => %{"lifeCycleStatus" => "ready", "privacyStatus" => "private"}
        }))
      end)

      # 2. Expect liveStreams POST success
      Req.Test.expect(YouTubeClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "stream_456",
          "cdn" => %{
            "ingestionInfo" => %{
              "ingestionAddress" => "rtmp://a.rtmp.youtube.com/live2",
              "streamName" => "stream_key_xyz"
            }
          }
        }))
      end)

      # 3. Expect liveBroadcasts/bind POST failure (Gap 6 check)
      Req.Test.expect(YouTubeClient, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => %{
            "message" => "Bind failed"
          }
        }))
      end)

      assert {:error, {400, "Bind failed"}} = StartLiveBroadcast.handler(%{
        title: "My Stream",
        scheduled_start_time: "2024-12-01T20:00:00Z"
      }, %{name: "TestAgent"})
    end
  end

  describe "SendLiveChatMessage" do
    alias Lux.Prisms.YouTube.SendLiveChatMessage

    test "successfully sends a live chat message" do
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/liveChat/messages"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json_body = Jason.decode!(body)
        assert json_body["snippet"]["liveChatId"] == "chat_123"
        assert json_body["snippet"]["textMessageDetails"]["messageText"] == "Hello, Chat!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "message_123",
          "snippet" => %{
            "textMessageDetails" => %{
              "messageText" => "Hello, Chat!"
            }
          }
        }))
      end)

      assert {:ok, %{
        sent: true,
        message_id: "message_123",
        message_text: "Hello, Chat!"
      }} = SendLiveChatMessage.handler(%{
        live_chat_id: "chat_123",
        message_text: "Hello, Chat!"
      }, %{name: "TestAgent"})
    end
  end

  describe "UploadVideo" do
    alias Lux.Prisms.YouTube.UploadVideo

    test "uploads a video successfully using resumable chunks" do
      # Create a temporary dummy file to upload
      temp_file = "test_upload_video.mp4"
      File.write!(temp_file, "dummy content for video file upload")

      on_exit(fn ->
        File.rm(temp_file)
      end)

      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/upload/youtube/v3/videos"
        assert conn.params["uploadType"] == "resumable"

        conn
        |> Plug.Conn.put_resp_header("location", "http://localhost/upload_session_abc")
        |> Plug.Conn.send_resp(200, "")
      end)

      # 2. Expect chunk upload PUT on session URL
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/upload_session_abc"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "video_789",
          "snippet" => %{
            "title" => "My Video"
          }
        }))
      end)

      assert {:ok, %{
        uploaded: true,
        video_id: "video_789",
        title: "My Video"
      }} = UploadVideo.handler(%{
        file_path: temp_file,
        title: "My Video",
        chunk_size: 1024 * 1024
      }, %{name: "TestAgent"})
    end
  end

  describe "Runtime string-key support & dry-run mode & parameter naming" do
    test "CreatePlaylist handler accepts string keys and respects dry-run flag" do
      # String keys and dry_run: true (no network requests made)
      assert {:ok, %{
        created: true,
        playlist_id: "mock_playlist_id",
        title: "Dry Run Playlist"
      }} = CreatePlaylist.handler(%{
        "title" => "Dry Run Playlist",
        "description" => "A description",
        "dry_run" => true
      }, %{name: "TestAgent"})
    end

    test "StartLiveBroadcast handler accepts string keys and respects dry-run flag" do
      # String keys and dry_run: true
      assert {:ok, %{
        created: true,
        broadcast_id: "mock_broadcast_id",
        title: "Dry Run Live Broadcast",
        stream_id: "mock_stream_id",
        ingestion_address: "rtmp://mock.youtube.com/live2",
        stream_name: "mock_stream_key"
      }} = StartLiveBroadcast.handler(%{
        "title" => "Dry Run Live Broadcast",
        "scheduled_start_time" => "2024-12-01T20:00:00Z",
        "dry_run" => true
      }, %{name: "TestAgent"})
    end

    test "SendLiveChatMessage handler accepts string keys and respects dry-run flag" do
      alias Lux.Prisms.YouTube.SendLiveChatMessage

      assert {:ok, %{
        sent: true,
        message_id: "mock_message_id",
        message_text: "Dry Run Msg"
      }} = SendLiveChatMessage.handler(%{
        "live_chat_id" => "chat_123",
        "message_text" => "Dry Run Msg",
        "dry_run" => true
      }, %{name: "TestAgent"})
    end
  end
end
