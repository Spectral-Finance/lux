defmodule Lux.Prisms.YouTube.ModerateCommentTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.ModerateComment
  alias Lux.Integrations.YouTube.Client, as: YouTubeClient

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully moderates a comment" do
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/comments/setModerationStatus"
        assert conn.params["id"] == "comment123"
        assert conn.params["moderationStatus"] == "rejected"
        assert conn.params["banAuthor"] == "true"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, %{
        moderated: true
      }} = ModerateComment.handler(%{
        comment_id: "comment123",
        moderation_status: "rejected",
        ban_author: true,
        dry_run: false,
        plug: YouTubeClient
      }, %{name: "TestAgent"})
    end
  end
end
