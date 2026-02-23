defmodule Lux.Lenses.YouTube.LiveBroadcasts.GetLiveStreamTest do
  @moduledoc """
  Test suite for the YouTube GetLiveStream lens.
  Verifies:
  - Live stream ingestion details and stream key retrieval
  - Stream health status
  - Stream not found handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.LiveBroadcasts.GetLiveStream

  @stream_id "stream_id_xyz"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves stream with ingestion details" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "liveStreams"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => @stream_id,
              "snippet" => %{
                "title" => "My Stream",
                "channelId" => "UCxxx",
                "publishedAt" => "2024-01-15T17:00:00.000Z"
              },
              "cdn" => %{
                "ingestionType" => "rtmp",
                "resolution" => "1080p",
                "frameRate" => "30fps",
                "ingestionInfo" => %{
                  "ingestionAddress" => "rtmp://a.rtmp.youtube.com/live2",
                  "backupIngestionAddress" => "rtmp://b.rtmp.youtube.com/live2",
                  "streamName" => "xxxx-xxxx-xxxx-xxxx",
                  "rtmpsIngestionAddress" => "rtmps://a.rtmps.youtube.com/live2/xxxx-xxxx"
                }
              },
              "status" => %{
                "streamStatus" => "active",
                "healthStatus" => %{
                  "status" => "good",
                  "lastIngestionTime" => "2024-01-15T18:00:10.000Z",
                  "configurationIssues" => []
                }
              },
              "contentDetails" => %{"isReusable" => false}
            }
          ]
        }))
      end)

      assert {:ok, result} = GetLiveStream.focus(%{"stream_id" => @stream_id}, %{})

      assert result.id == @stream_id
      assert result.title == "My Stream"
      assert result.ingestion_type == "rtmp"
      assert result.resolution == "1080p"
      assert result.frame_rate == "30fps"
      assert result.ingestion_address == "rtmp://a.rtmp.youtube.com/live2"
      assert result.stream_key == "xxxx-xxxx-xxxx-xxxx"
      assert result.stream_status == "active"
      assert result.health_status == "good"
      assert result.is_reusable == false
    end

    test "handles stream not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:error, %{message: "Stream not found"}} =
               GetLiveStream.focus(%{"stream_id" => "nonexistent"}, %{})
    end

    test "handles unauthorized error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "error" => %{"message" => "Request had invalid authentication credentials."}
        }))
      end)

      assert {:error, %{message: "Request had invalid authentication credentials."}} =
               GetLiveStream.focus(%{"stream_id" => @stream_id}, %{})
    end
  end
end
