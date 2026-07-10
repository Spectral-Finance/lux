defmodule Lux.Lenses.YouTube.ListCommentThreadsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.YouTube.ListCommentThreads
  alias Lux.Integrations.YouTube.Client, as: YouTubeClient

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/1" do
    test "successfully fetches comment threads" do
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/youtube/v3/commentThreads"
        assert conn.params["videoId"] == "dQw4w9WgXcQ"
        assert conn.params["part"] == "snippet,replies"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "items" => [
            %{
              "id" => "comment123",
              "snippet" => %{
                "videoId" => "dQw4w9WgXcQ",
                "topLevelComment" => %{
                  "snippet" => %{
                    "textDisplay" => "Great video!",
                    "textOriginal" => "Great video!",
                    "authorDisplayName" => "User1",
                    "likeCount" => 5
                  }
                },
                "totalReplyCount" => 0
              }
            }
          ]
        }))
      end)

      assert {:ok, result} = ListCommentThreads.focus(%{
        video_id: "dQw4w9WgXcQ",
        plug: YouTubeClient
      })

      assert length(result.comments) == 1
      comment = hd(result.comments)
      assert comment.id == "comment123"
      assert comment.text_display == "Great video!"
      assert comment.author_display_name == "User1"
    end
  end
end
