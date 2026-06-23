defmodule Lux.Lenses.YouTube.GetVideoDetailsTest do
  @moduledoc """
  Test suite for the GetVideoDetails module.
  These tests verify the lens's ability to:
  - Fetch video details from YouTube
  - Handle missing videos
  - Handle YouTube API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.GetVideoDetails

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully fetches video details" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/videos"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "dQw4w9WgXcQ",
              "snippet" => %{
                "title" => "Rick Astley - Never Gonna Give You Up",
                "description" => "The official video",
                "channelTitle" => "Rick Astley",
                "publishedAt" => "2009-10-25T06:57:33Z",
                "thumbnails" => %{
                  "default" => %{"url" => "https://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg"}
                }
              },
              "statistics" => %{
                "viewCount" => "1500000000",
                "likeCount" => "15000000",
                "commentCount" => "3000000"
              },
              "contentDetails" => %{
                "duration" => "PT3M33S"
              }
            }
          ]
        }))
      end)

      assert {:ok, %{
        video_id: "dQw4w9WgXcQ",
        title: "Rick Astley - Never Gonna Give You Up",
        description: "The official video",
        channel_title: "Rick Astley",
        published_at: "2009-10-25T06:57:33Z",
        view_count: "1500000000",
        like_count: "15000000",
        comment_count: "3000000",
        duration: "PT3M33S",
        thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg"
      }} = GetVideoDetails.focus(%{
        "id" => "dQw4w9WgXcQ"
      }, %{})
    end

    test "handles video not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/videos"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => []
        }))
      end)

      assert {:error, %{"message" => "Video not found"}} = GetVideoDetails.focus(%{
        "id" => "nonexistent_video"
      }, %{})
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/videos"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "error" => %{
            "message" => "Forbidden"
          }
        }))
      end)

      assert {:error, %{"error" => %{"message" => "Forbidden"}}} = GetVideoDetails.focus(%{
        "id" => "dQw4w9WgXcQ"
      }, %{})
    end
  end
end
