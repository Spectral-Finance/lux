defmodule Lux.Lenses.YouTube.LiveBroadcasts.GetLiveBroadcastTest do
  @moduledoc """
  Test suite for the YouTube GetLiveBroadcast lens.
  Verifies:
  - Live broadcast status and details retrieval
  - Concurrent viewers count
  - Broadcast not found handling
  - Error propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.LiveBroadcasts.GetLiveBroadcast

  @broadcast_id "broadcast_id_abc"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves live broadcast details" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "liveBroadcasts"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => @broadcast_id,
              "snippet" => %{
                "title" => "My Live Stream",
                "description" => "Live from here!",
                "channelId" => "UCxxx",
                "publishedAt" => "2024-01-15T10:00:00.000Z",
                "scheduledStartTime" => "2024-01-15T18:00:00.000Z",
                "actualStartTime" => "2024-01-15T18:00:05.000Z",
                "liveChatId" => "chat_id_xyz",
                "thumbnails" => %{"high" => %{"url" => "https://example.com/thumb.jpg"}}
              },
              "status" => %{
                "lifeCycleStatus" => "live",
                "privacyStatus" => "public",
                "recordingStatus" => "recording"
              },
              "contentDetails" => %{
                "boundStreamId" => "stream_id_123",
                "enableDvr" => true,
                "enableEmbed" => true,
                "recordFromStart" => true
              },
              "statistics" => %{
                "concurrentViewers" => "1523",
                "totalChatCount" => "45678"
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = GetLiveBroadcast.focus(%{"broadcast_id" => @broadcast_id}, %{})

      assert result.id == @broadcast_id
      assert result.title == "My Live Stream"
      assert result.life_cycle_status == "live"
      assert result.bound_stream_id == "stream_id_123"
      assert result.concurrent_viewers == 1523
      assert result.total_chat_count == 45_678
      assert result.enable_dvr == true
    end

    test "handles broadcast not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:error, %{message: "Broadcast not found"}} =
               GetLiveBroadcast.focus(%{"broadcast_id" => "nonexistent"}, %{})
    end

    test "handles unauthorized error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "error" => %{"message" => "Invalid Credentials"}
        }))
      end)

      assert {:error, %{message: "Invalid Credentials"}} =
               GetLiveBroadcast.focus(%{"broadcast_id" => @broadcast_id}, %{})
    end
  end
end
