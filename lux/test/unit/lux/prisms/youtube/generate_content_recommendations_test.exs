defmodule Lux.Prisms.YouTube.GenerateContentRecommendationsTest do
  @moduledoc """
  Test suite for the GenerateContentRecommendations prism.
  Verifies the prism can:
  - Generate a content calendar from trending topics
  - Use provided trending_topics without calling the lens
  - Return strategy summary and topics_analyzed count
  - Respect num_recommendations limit
  - Fill gaps with curated ideas when trending topics are sparse
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.YouTube.GenerateContentRecommendations

  @agent %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2 with provided trending_topics" do
    test "generates content calendar from provided topics without API call" do
      trending_topics = [
        %{
          video_id: "vid001",
          title: "Elixir OTP Tutorial",
          channel_title: "CodeChannel",
          trending_score: 90,
          published_at: "2024-01-15T00:00:00Z"
        },
        %{
          video_id: "vid002",
          title: "Phoenix LiveView in 1 Hour",
          channel_title: "ElixirPros",
          trending_score: 75,
          published_at: "2024-01-16T00:00:00Z"
        }
      ]

      assert {:ok, result} = GenerateContentRecommendations.handler(
        %{
          "topic_focus" => "elixir programming",
          "trending_topics" => trending_topics,
          "num_recommendations" => 5
        },
        @agent
      )

      assert length(result.content_calendar) == 5
      assert result.topics_analyzed == 2
      assert is_binary(result.strategy_summary)
      assert String.contains?(result.strategy_summary, "elixir programming")

      first = hd(result.content_calendar)
      assert Map.has_key?(first, :title)
      assert Map.has_key?(first, :priority)
      assert Map.has_key?(first, :estimated_views)
      assert Map.has_key?(first, :suggested_format)
      assert Map.has_key?(first, :calendar_week)
    end

    test "respects num_recommendations limit" do
      topics = Enum.map(1..10, fn i ->
        %{video_id: "vid#{i}", title: "Video #{i}", trending_score: 60}
      end)

      assert {:ok, result} = GenerateContentRecommendations.handler(
        %{
          "topic_focus" => "programming",
          "trending_topics" => topics,
          "num_recommendations" => 3
        },
        @agent
      )

      assert length(result.content_calendar) == 3
    end

    test "assigns sequential calendar_week numbers" do
      topics = [%{video_id: "v1", title: "Topic A", trending_score: 80}]

      assert {:ok, result} = GenerateContentRecommendations.handler(
        %{
          "topic_focus" => "tech",
          "trending_topics" => topics,
          "num_recommendations" => 3
        },
        @agent
      )

      weeks = Enum.map(result.content_calendar, & &1.calendar_week)
      assert weeks == [1, 2, 3]
    end

    test "assigns high priority to topics with trending_score >= 80" do
      topics = [%{video_id: "v1", title: "Hot Topic", trending_score: 95}]

      assert {:ok, result} = GenerateContentRecommendations.handler(
        %{
          "topic_focus" => "tech",
          "trending_topics" => topics,
          "num_recommendations" => 1
        },
        @agent
      )

      assert hd(result.content_calendar).priority == "high"
    end
  end

  describe "handler/2 with live API call" do
    test "fetches trending topics and generates recommendations" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => %{"videoId" => "vid_a"},
              "snippet" => %{
                "title" => "Rust for Beginners",
                "description" => "Learn Rust",
                "channelId" => "UCrust",
                "channelTitle" => "RustChan",
                "publishedAt" => "2024-02-01T00:00:00Z",
                "thumbnails" => %{"high" => %{"url" => "https://img.youtube.com/vi/vid_a/hqdefault.jpg"}}
              }
            }
          ],
          "pageInfo" => %{"totalResults" => 100, "resultsPerPage" => 10}
        }))
      end)

      assert {:ok, result} = GenerateContentRecommendations.handler(
        %{
          "topic_focus" => "rust programming",
          "num_recommendations" => 3
        },
        @agent
      )

      assert length(result.content_calendar) == 3
      assert result.topics_analyzed >= 1
      assert is_binary(result.strategy_summary)
    end
  end
end
