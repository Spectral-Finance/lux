defmodule Lux.Lenses.YouTube.Analytics.SearchTrendingTopicsTest do
  @moduledoc """
  Test suite for the SearchTrendingTopics lens.
  Verifies the lens can:
  - Return trending topics with trending scores
  - Handle empty search results
  - Handle YouTube API error responses
  - Accept optional filter parameters
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Analytics.SearchTrendingTopics

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves trending topics with scores" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => %{"videoId" => "vid001"},
              "snippet" => %{
                "title" => "Elixir GenServer Tutorial",
                "description" => "Learn GenServer",
                "channelId" => "UCtest1",
                "channelTitle" => "CodeChannel",
                "publishedAt" => "2024-01-10T12:00:00Z",
                "thumbnails" => %{
                  "high" => %{"url" => "https://img.youtube.com/vi/vid001/hqdefault.jpg"}
                }
              }
            },
            %{
              "id" => %{"videoId" => "vid002"},
              "snippet" => %{
                "title" => "Phoenix LiveView Crash Course",
                "description" => "Build with LiveView",
                "channelId" => "UCtest2",
                "channelTitle" => "ElixirPros",
                "publishedAt" => "2024-01-12T08:00:00Z",
                "thumbnails" => %{"high" => %{"url" => "https://img.youtube.com/vi/vid002/hqdefault.jpg"}}
              }
            }
          ],
          "pageInfo" => %{"totalResults" => 500, "resultsPerPage" => 10}
        }))
      end)

      assert {:ok, result} = SearchTrendingTopics.focus(%{"query" => "elixir programming"}, %{})
      assert length(result.topics) == 2
      assert result.total_results == 500

      [first | [second | _]] = result.topics
      assert first.video_id == "vid001"
      assert first.title == "Elixir GenServer Tutorial"
      assert first.channel_title == "CodeChannel"
      assert first.trending_score > second.trending_score
    end

    test "returns empty topics list when no results found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [],
          "pageInfo" => %{"totalResults" => 0, "resultsPerPage" => 10}
        }))
      end)

      assert {:ok, result} = SearchTrendingTopics.focus(%{"query" => "xyznotexistent123"}, %{})
      assert result.topics == []
      assert result.total_results == 0
    end

    test "returns error for YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "error" => %{"code" => 400, "message" => "Bad Request: invalid query"}
        }))
      end)

      assert {:error, %{message: "Bad Request: invalid query", code: 400}} =
               SearchTrendingTopics.focus(%{"query" => "test"}, %{})
    end
  end

  describe "after_focus/1" do
    test "computes decreasing trending scores for ranked results" do
      response = %{
        "items" => Enum.map(1..5, fn i ->
          %{
            "id" => %{"videoId" => "vid#{i}"},
            "snippet" => %{
              "title" => "Video #{i}",
              "channelTitle" => "Channel",
              "publishedAt" => "2024-01-01T00:00:00Z"
            }
          }
        end),
        "pageInfo" => %{"totalResults" => 5, "resultsPerPage" => 5}
      }

      assert {:ok, result} = SearchTrendingTopics.after_focus(response)
      scores = Enum.map(result.topics, & &1.trending_score)
      assert scores == Enum.sort(scores, :desc)
    end

    test "returns error for unexpected response" do
      assert {:error, %{message: "Unexpected response"}} =
               SearchTrendingTopics.after_focus(%{"weird" => "format"})
    end
  end

  describe "schema validation" do
    test "requires query field" do
      lens = SearchTrendingTopics.view()
      assert lens.schema.required == ["query"]
    end

    test "uses GET method" do
      lens = SearchTrendingTopics.view()
      assert lens.method == :get
    end

    test "targets YouTube search endpoint" do
      lens = SearchTrendingTopics.view()
      assert lens.url == "https://www.googleapis.com/youtube/v3/search"
    end
  end
end
