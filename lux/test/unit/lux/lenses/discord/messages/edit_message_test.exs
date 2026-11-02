defmodule Lux.Lenses.Discord.Messages.EditMessageTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Messages.EditMessage

  @channel_id "123456789012345678"
  @message_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "edits message content" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages/:message_id"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["content"] == "Edited message text"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "id" => @message_id,
            "channel_id" => @channel_id,
            "content" => decoded["content"],
            "edited_timestamp" => "2026-11-02T12:05:00Z"
          })
        )
      end)

      assert {:ok, result} =
               EditMessage.focus(
                 %{
                   "channel_id" => @channel_id,
                   "message_id" => @message_id,
                   "content" => "Edited message text"
                 },
                 %{}
               )

      assert result.id == @message_id
      assert result.content == "Edited message text"
    end
  end
end
