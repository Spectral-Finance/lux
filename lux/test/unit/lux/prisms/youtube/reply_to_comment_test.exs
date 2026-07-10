defmodule Lux.Prisms.YouTube.ReplyToCommentTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.YouTube.ReplyToComment
  alias Lux.Integrations.YouTube.Client, as: YouTubeClient

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully replies to a comment" do
      Req.Test.expect(YouTubeClient, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/youtube/v3/comments"
        assert conn.params["part"] == "snippet"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json_body = Jason.decode!(body)
        assert json_body["snippet"]["parentId"] == "parent123"
        assert json_body["snippet"]["textOriginal"] == "Thanks!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "id" => "reply123",
          "snippet" => %{
            "textOriginal" => "Thanks!"
          }
        }))
      end)

      assert {:ok, %{
        replied: true,
        reply_id: "reply123"
      }} = ReplyToComment.handler(%{
        parent_id: "parent123",
        text: "Thanks!",
        dry_run: false,
        plug: YouTubeClient
      }, %{name: "TestAgent"})
    end
  end
end
