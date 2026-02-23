defmodule Lux.Lenses.YouTube.Analytics.GetVideoAnalyticsTest do
  @moduledoc """
  Test suite for the GetVideoAnalytics lens.
  Verifies the lens can:
  - Retrieve video analytics and compute engagement metrics
  - Handle not found (empty items) responses
  - Handle YouTube API error responses
  - Compute performance_score and estimated_revenue_potential
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Analytics.GetVideoAnalytics

  @video_id "dQw4w9WgXcQ"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves video analytics with computed metrics" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [%{
            "id" => @video_id,
            "snippet" => %{
              "title" => "Never Gonna Give You Up",
              "description" => "Official music video",
              "channelId" => "UCxxxxxx",
              "channelTitle" => "Rick Astley",
              "publishedAt" => "2009-10-25T06:57:33Z",
              "tags" => ["rick astley", "never gonna give you up", "pop"],
              "categoryId" => "10"
            },
            "statistics" => %{
              "viewCount" => "1300000000",
              "likeCount" => "15000000",
              "commentCount" => "2500000",
              "favoriteCount" => "0"
            },
            "contentDetails" => %{
              "duration" => "PT3M33S",
              "definition" => "hd"
            }
          }]
        }))
      end)

      assert {:ok, result} = GetVideoAnalytics.focus(%{"video_id" => @video_id}, %{})
      assert result.video_id == @video_id
      assert result.title == "Never Gonna Give You Up"
      assert result.view_count == 1_300_000_000
      assert result.like_count == 15_000_000
      assert result.comment_count == 2_500_000
      assert result.duration == "PT3M33S"
      assert result.engagement_rate == 1.35
      assert result.performance_score == 70
      assert result.estimated_revenue_potential == 2_600_000.0
    end

    test "computes zero engagement for video with no views" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [%{
            "id" => "newvid123",
            "snippet" => %{"title" => "New Video"},
            "statistics" => %{
              "viewCount" => "0",
              "likeCount" => "0",
              "commentCount" => "0"
            },
            "contentDetails" => %{"duration" => "PT5M"}
          }]
        }))
      end)

      assert {:ok, result} = GetVideoAnalytics.focus(%{"video_id" => "newvid123"}, %{})
      assert result.view_count == 0
      assert result.engagement_rate == 0.0
      assert result.estimated_revenue_potential == 0.0
    end

    test "returns error when video is not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:error, %{message: "Video not found", code: "VIDEO_NOT_FOUND"}} =
               GetVideoAnalytics.focus(%{"video_id" => "nonexistent"}, %{})
    end

    test "returns error for YouTube API error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "error" => %{
            "code" => 403,
            "message" => "The caller does not have permission"
          }
        }))
      end)

      assert {:error, %{message: "The caller does not have permission", code: 403}} =
               GetVideoAnalytics.focus(%{"video_id" => @video_id}, %{})
    end
  end

  describe "after_focus/1" do
    test "handles missing statistics gracefully" do
      response = %{
        "items" => [%{
          "id" => "vid1",
          "snippet" => %{"title" => "Test"},
          "statistics" => %{},
          "contentDetails" => %{}
        }]
      }

      assert {:ok, result} = GetVideoAnalytics.after_focus(response)
      assert result.view_count == 0
      assert result.like_count == 0
      assert result.engagement_rate == 0.0
    end

    test "returns error for unexpected response format" do
      assert {:error, %{message: "Unexpected response"}} =
               GetVideoAnalytics.after_focus(%{"unexpected" => "data"})
    end
  end

  describe "schema validation" do
    test "requires video_id field" do
      lens = GetVideoAnalytics.view()
      assert lens.schema.required == ["video_id"]
    end

    test "uses GET method" do
      lens = GetVideoAnalytics.view()
      assert lens.method == :get
    end

    test "targets YouTube videos endpoint" do
      lens = GetVideoAnalytics.view()
      assert lens.url == "https://www.googleapis.com/youtube/v3/videos"
    end
  end
end
