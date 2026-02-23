defmodule Lux.Prisms.YouTube.AnalyzeVideoPerformanceTest do
  @moduledoc """
  Test suite for the AnalyzeVideoPerformance prism.
  Verifies the prism can:
  - Classify performance tier (viral/above_average/average/below_average)
  - Compute content_score from analytics data
  - Generate actionable recommendations
  - Propagate errors from the GetVideoAnalytics lens
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.AnalyzeVideoPerformance

  @agent %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "classifies viral video and generates momentum recommendations" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [%{
            "id" => "viralvid",
            "snippet" => %{
              "title" => "Viral Hit",
              "description" => "This went viral",
              "tags" => ["viral", "trending", "popular", "music", "2024"],
              "channelId" => "UCtest",
              "channelTitle" => "TestChannel"
            },
            "statistics" => %{
              "viewCount" => "5000000",
              "likeCount" => "500000",
              "commentCount" => "100000"
            },
            "contentDetails" => %{"duration" => "PT4M"}
          }]
        }))
      end)

      assert {:ok, result} = AnalyzeVideoPerformance.handler(
        %{"video_id" => "viralvid", "channel_avg_views" => 50_000},
        @agent
      )

      assert result.video_id == "viralvid"
      assert result.performance_tier == "viral"
      assert result.content_score >= 70
      assert is_list(result.recommendations)
      assert length(result.recommendations) > 0
      assert result.metrics.view_count == 5_000_000
    end

    test "classifies below_average video and generates improvement recommendations" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [%{
            "id" => "lowvid",
            "snippet" => %{
              "title" => "My Video",
              "description" => "Short",
              "tags" => [],
              "channelId" => "UCtest",
              "channelTitle" => "TestChannel"
            },
            "statistics" => %{
              "viewCount" => "100",
              "likeCount" => "1",
              "commentCount" => "0"
            },
            "contentDetails" => %{"duration" => "PT2M"}
          }]
        }))
      end)

      assert {:ok, result} = AnalyzeVideoPerformance.handler(
        %{"video_id" => "lowvid", "channel_avg_views" => 50_000},
        @agent
      )

      assert result.performance_tier == "below_average"
      assert result.content_score < 50
      # Should have SEO recommendations for low-performing video
      assert Enum.any?(result.recommendations, &String.contains?(&1, ["title", "tag", "description", "thumbnail"]))
    end

    test "propagates error when video is not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:error, %{message: "Video not found"}} =
               AnalyzeVideoPerformance.handler(%{"video_id" => "nonexistent"}, @agent)
    end

    test "uses default channel_avg_views when not provided" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [%{
            "id" => "testvid",
            "snippet" => %{
              "title" => "Test Video",
              "description" => "A test video description",
              "tags" => ["test"],
              "channelId" => "UCtest",
              "channelTitle" => "Test"
            },
            "statistics" => %{
              "viewCount" => "25000",
              "likeCount" => "500",
              "commentCount" => "50"
            },
            "contentDetails" => %{"duration" => "PT8M"}
          }]
        }))
      end)

      assert {:ok, result} = AnalyzeVideoPerformance.handler(%{"video_id" => "testvid"}, @agent)
      assert result.performance_tier in ["viral", "above_average", "average", "below_average"]
    end
  end
end
