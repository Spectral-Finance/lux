defmodule Lux.Lenses.Telegram.Messages.DeleteMessageTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Messages.DeleteMessage

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully deletes a message" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/deleteMessage")
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => true
        }))
      end)

      assert {:ok, true} = DeleteMessage.focus(%{
        chat_id: "12345",
        message_id: 1
      }, %{})
    end
  end
end
