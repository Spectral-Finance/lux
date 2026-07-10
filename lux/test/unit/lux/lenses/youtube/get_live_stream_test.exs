defmodule Lux.Lenses.YouTube.GetLiveStreamTest do
  @moduledoc """
  Test suite for the GetLiveStream module.
  These tests verify the lens's ability to:
  - Fetch live broadcast information from YouTube
  - Handle YouTube API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.GetLiveStream

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches live broadcasts" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/liveBroadcasts"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "broadcast_abc123",
              "snippet" => %{
                "title" => "Live Coding Session",
                "description" => "Building an Elixir app",
                "scheduledStartTime" => "2024-01-01T20:00:00Z",
                "actualStartTime" => "2024-01-01T20:01:00Z",
                "actualEndTime" => nil
              },
              "status" => %{
                "lifeCycleStatus" => "live",
                "privacyStatus" => "public",
                "recordingStatus" => "recording"
              },
              "contentDetails" => %{
                "boundStreamId" => "stream_xyz789",
                "monitorStream" => %{
                  "enableMonitorStream" => true
                }
              }
            }
          ]
        }))
      end)

      assert {:ok, [
        %{
          broadcast_id: "broadcast_abc123",
          title: "Live Coding Session",
          description: "Building an Elixir app",
          scheduled_start_time: "2024-01-01T20:00:00Z",
          actual_start_time: "2024-01-01T20:01:00Z",
          life_cycle_status: "live",
          privacy_status: "public",
          recording_status: "recording",
          bound_stream_id: "stream_xyz789"
        }
      ]} = GetLiveStream.focus(%{
        "broadcastStatus" => "active"
      }, %{})
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/liveBroadcasts"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "error" => %{
            "message" => "Invalid Credentials"
          }
        }))
      end)

      assert {:error, %{"error" => %{"message" => "Invalid Credentials"}}} = GetLiveStream.focus(%{
        "broadcastStatus" => "active"
      }, %{})
    end
  end
end
