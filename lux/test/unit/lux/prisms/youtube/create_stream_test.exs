defmodule Lux.Prisms.YouTube.CreateStreamTest do
  @moduledoc """
  Test suite for the YouTube CreateStream prism.
  Verifies:
  - Successful stream creation with RTMP details
  - Stream binding to broadcast
  - Error handling
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.CreateStream

  setup do
    Application.put_env(:lux, :api_keys, youtube_oauth_token: "test_oauth_token")
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a stream without binding" do
      Req.Test.expect(Lux.Prism, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path =~ "liveStreams"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "newStreamId",
          "snippet" => %{"title" => "My Stream", "channelId" => "UCxxx"},
          "cdn" => %{
            "ingestionType" => "rtmp",
            "resolution" => "1080p",
            "frameRate" => "30fps",
            "ingestionInfo" => %{
              "ingestionAddress" => "rtmp://a.rtmp.youtube.com/live2",
              "backupIngestionAddress" => "rtmp://b.rtmp.youtube.com/live2",
              "streamName" => "test-xxxx-xxxx-xxxx"
            }
          },
          "status" => %{"streamStatus" => "inactive"},
          "contentDetails" => %{"isReusable" => false}
        }))
      end)

      assert {:ok, result} = CreateStream.handler(%{
        "title" => "My Stream",
        "resolution" => "1080p",
        "frame_rate" => "30fps"
      }, %{})

      assert result.stream_id == "newStreamId"
      assert result.title == "My Stream"
      assert result.ingestion_address == "rtmp://a.rtmp.youtube.com/live2"
      assert result.stream_key == "test-xxxx-xxxx-xxxx"
      assert result.status == "created"
      refute Map.has_key?(result, :bound_to_broadcast)
    end

    test "creates stream and binds to broadcast" do
      # First call: create stream
      Req.Test.expect(Lux.Prism, fn conn ->
        assert conn.request_path =~ "liveStreams"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "streamId123",
          "snippet" => %{"title" => "My Stream"},
          "cdn" => %{
            "ingestionType" => "rtmp",
            "ingestionInfo" => %{
              "ingestionAddress" => "rtmp://a.rtmp.youtube.com/live2",
              "streamName" => "key-xxxx"
            }
          }
        }))
      end)

      # Second call: bind to broadcast
      Req.Test.expect(Lux.Prism, fn conn ->
        assert conn.request_path =~ "bind"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "broadcastId456",
          "contentDetails" => %{"boundStreamId" => "streamId123"}
        }))
      end)

      assert {:ok, result} = CreateStream.handler(%{
        "title" => "My Stream",
        "broadcast_id" => "broadcastId456"
      }, %{})

      assert result.stream_id == "streamId123"
      assert result.bound_to_broadcast == "broadcastId456"
    end

    test "handles stream creation error" do
      Req.Test.expect(Lux.Prism, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{"message" => "Insufficient permissions"}
        }))
      end)

      assert {:error, %{message: "Insufficient permissions"}} =
               CreateStream.handler(%{"title" => "My Stream"}, %{})
    end
  end
end
