defmodule Lux.Lenses.YouTube.Community.ListCommentsTest do
  @moduledoc """
  Test suite for the ListComments lens.
  These tests verify the lens's ability to:
  - List reply comments within a comment thread
  - Handle pagination parameters
  - Process YouTube API error responses
  - Return structured reply data
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.YouTube.Community.ListComments

  @parent_id "Ugw_thread_001"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists reply comments" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/comments"

        query = URI.decode_query(conn.query_string)
        assert query["parentId"] == @parent_id
        assert query["part"] == "snippet"
        assert query["maxResults"] == "20"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "items" => [
              %{
                "id" => "reply_001",
                "snippet" => %{
                  "parentId" => @parent_id,
                  "textDisplay" => "Thanks for the reply!",
                  "authorDisplayName" => "ReplyUser",
                  "likeCount" => 5,
                  "publishedAt" => "2024-01-02T00:00:00Z",
                  "updatedAt" => "2024-01-02T00:00:00Z"
                }
              }
            ]
          })
        )
      end)

      assert {:ok, result} = ListComments.focus(%{parent_id: @parent_id}, %{})
      assert result.count == 1
      [comment] = result.comments
      assert comment.id == "reply_001"
      assert comment.parent_id == @parent_id
      assert comment.text == "Thanks for the reply!"
      assert comment.author == "ReplyUser"
      assert comment.like_count == 5
    end

    test "lists comments with custom max_results" do
      Req.Test.expect(Lux.Lens, fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["maxResults"] == "50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, result} =
               ListComments.focus(%{parent_id: @parent_id, max_results: 50}, %{})

      assert result.count == 0
    end

    test "handles empty items list" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, result} = ListComments.focus(%{parent_id: @parent_id}, %{})
      assert result.comments == []
      assert result.count == 0
    end

    test "handles YouTube API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          403,
          Jason.encode!(%{
            "error" => %{"message" => "Forbidden"}
          })
        )
      end)

      assert {:error, %{message: "Forbidden"}} =
               ListComments.focus(%{parent_id: @parent_id}, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = ListComments.view()
      assert lens.schema.required == ["parent_id"]
    end

    test "validates max_results parameter" do
      lens = ListComments.view()
      max = lens.schema.properties.max_results
      assert max.type == :integer
      assert max.minimum == 1
      assert max.maximum == 100
    end
  end
end
