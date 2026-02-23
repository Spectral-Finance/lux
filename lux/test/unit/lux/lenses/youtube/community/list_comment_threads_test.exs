defmodule Lux.Lenses.YouTube.Community.ListCommentThreadsTest do
  @moduledoc """
  Test suite for the ListCommentThreads lens.
  These tests verify the lens's ability to:
  - List comment threads for a YouTube video
  - Handle default and custom parameters
  - Process YouTube API error responses
  - Return structured thread data with engagement metrics
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Community.ListCommentThreads

  @video_id "dQw4w9WgXcQ"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists comment threads with default parameters" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/commentThreads"

        query = URI.decode_query(conn.query_string)
        assert query["videoId"] == @video_id
        assert query["part"] == "snippet,replies"
        assert query["maxResults"] == "20"
        assert query["order"] == "relevance"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "items" => [
              %{
                "id" => "thread_001",
                "snippet" => %{
                  "videoId" => @video_id,
                  "totalReplyCount" => 3,
                  "canReply" => true,
                  "topLevelComment" => %{
                    "snippet" => %{
                      "textDisplay" => "Great video!",
                      "authorDisplayName" => "TestUser",
                      "likeCount" => 42,
                      "publishedAt" => "2024-01-01T00:00:00Z"
                    }
                  }
                }
              }
            ]
          })
        )
      end)

      assert {:ok, result} = ListCommentThreads.focus(%{video_id: @video_id}, %{})
      assert result.count == 1
      [thread] = result.threads
      assert thread.id == "thread_001"
      assert thread.video_id == @video_id
      assert thread.text == "Great video!"
      assert thread.author == "TestUser"
      assert thread.like_count == 42
      assert thread.reply_count == 3
      assert thread.can_reply == true
    end

    test "successfully lists threads with custom order and max_results" do
      Req.Test.expect(Lux.Lens, fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["maxResults"] == "50"
        assert query["order"] == "time"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, result} =
               ListCommentThreads.focus(
                 %{video_id: @video_id, max_results: 50, order: "time"},
                 %{}
               )

      assert result.count == 0
      assert result.threads == []
    end

    test "handles empty items list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, result} = ListCommentThreads.focus(%{video_id: @video_id}, %{})
      assert result.threads == []
      assert result.count == 0
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          403,
          Jason.encode!(%{
            "error" => %{"message" => "The caller does not have permission"}
          })
        )
      end)

      assert {:error, %{message: "The caller does not have permission"}} =
               ListCommentThreads.focus(%{video_id: @video_id}, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = ListCommentThreads.view()
      assert lens.schema.required == ["video_id"]
    end

    test "validates parameter types and defaults" do
      lens = ListCommentThreads.view()

      max_results = lens.schema.properties.max_results
      assert max_results.type == :integer
      assert max_results.minimum == 1
      assert max_results.maximum == 100
      assert max_results.default == 20

      order = lens.schema.properties.order
      assert order.type == :string
      assert "time" in order.enum
      assert "relevance" in order.enum
    end
  end
end
