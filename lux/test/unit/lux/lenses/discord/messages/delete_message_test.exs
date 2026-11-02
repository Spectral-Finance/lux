defmodule Lux.Lenses.Discord.Messages.DeleteMessageTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Messages.DeleteMessage

  @channel_id "123456789012345678"
  @message_id "987654321098765432"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "deletes message from channel" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages/:message_id"

        conn
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, result} =
               DeleteMessage.focus(
                 %{"channel_id" => @channel_id, "message_id" => @message_id},
                 %{}
               )

      assert result.deleted == true
    end
  end
end
