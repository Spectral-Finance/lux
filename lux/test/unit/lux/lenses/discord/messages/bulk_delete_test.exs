defmodule Lux.Lenses.Discord.Messages.BulkDeleteTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Discord.Messages.BulkDelete

  @channel_id "123456789012345678"
  @messages ["987654321098765432", "987654321098765433", "987654321098765434"]

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "bulk deletes messages from channel" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/channels/:channel_id/messages/bulk-delete"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["messages"]) == 3

        conn
        |> Plug.Conn.send_resp(204, "")
      end)

      assert {:ok, result} =
               BulkDelete.focus(
                 %{"channel_id" => @channel_id, "messages" => @messages},
                 %{}
               )

      assert result.bulk_deleted == true
    end
  end
end
