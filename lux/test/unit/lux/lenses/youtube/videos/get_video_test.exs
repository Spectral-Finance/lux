defmodule Lux.Lenses.YouTube.Videos.GetVideoTest do
  @moduledoc """
  Test suite for the YouTube GetVideo lens.
  Verifies:
  - Video metadata, statistics, and content detail retrieval
  - Live streaming details for live/upcoming videos
  - Missing video handling
  - Error response propagation
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Videos.GetVideo

  @video_id "dQw4w9WgXcQ"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves video with full metadata" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ "videos"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => @video_id,
              "snippet" => %{
                "title" => "Never Gonna Give You Up",
                "description" => "The official video.",
                "channelId" => "UCuAXFkgsw1L7xaCfnd5JJOw",
                "channelTitle" => "Rick Astley",
                "publishedAt" => "2009-10-25T06:57:33.000Z",
                "thumbnails" => %{"high" => %{"url" => "https://i.ytimg.com/vi/#{@video_id}/hqdefault.jpg"}},
                "tags" => ["rick astley", "never gonna give you up"],
                "liveBroadcastContent" => "none"
              },
              "statistics" => %{
                "viewCount" => "1400000000",
                "likeCount" => "16000000",
                "commentCount" => "1200000"
              },
              "contentDetails" => %{
                "duration" => "PT3M33S",
                "definition" => "hd",
                "caption" => "true"
              },
              "status" => %{
                "privacyStatus" => "public",
                "uploadStatus" => "processed"
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = GetVideo.focus(%{"video_id" => @video_id}, %{})

      assert result.id == @video_id
      assert result.title == "Never Gonna Give You Up"
      assert result.channel_title == "Rick Astley"
      assert result.view_count == 1_400_000_000
      assert result.like_count == 16_000_000
      assert result.duration == "PT3M33S"
      assert result.definition == "hd"
      assert result.privacy_status == "public"
      assert result.live_broadcast_content == "none"
    end

    test "retrieves live stream details for active broadcast" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "liveVideoId",
              "snippet" => %{
                "title" => "Live Now!",
                "channelId" => "UCxxx",
                "channelTitle" => "Live Channel",
                "liveBroadcastContent" => "live"
              },
              "statistics" => %{"viewCount" => "5000"},
              "contentDetails" => %{"duration" => "P0D"},
              "status" => %{"privacyStatus" => "public"},
              "liveStreamingDetails" => %{
                "scheduledStartTime" => "2024-01-15T18:00:00.000Z",
                "actualStartTime" => "2024-01-15T18:00:05.000Z",
                "concurrentViewers" => "1523"
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = GetVideo.focus(%{"video_id" => "liveVideoId"}, %{})
      assert result.live_broadcast_content == "live"
      assert result.concurrent_viewers == 1523
      assert result.actual_start_time == "2024-01-15T18:00:05.000Z"
    end

    test "handles video not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:error, %{message: "Video not found"}} =
               GetVideo.focus(%{"video_id" => "nonexistent123"}, %{})
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{"message" => "The caller does not have permission"}
        }))
      end)

      assert {:error, %{message: "The caller does not have permission"}} =
               GetVideo.focus(%{"video_id" => @video_id}, %{})
    end
  end
end
