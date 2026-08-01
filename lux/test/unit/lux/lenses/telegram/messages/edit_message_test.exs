defmodule Lux.Lenses.Telegram.Messages.EditMessageTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Messages.EditMessage

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully edits a message" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/editMessageText")
        
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["chat_id"] == "12345"
        assert params["message_id"] == 1
        assert params["text"] == "Edited Text"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "text" => "Edited Text"
          }
        }))
      end)

      assert {:ok, result} = EditMessage.focus(%{
        chat_id: "12345",
        message_id: 1,
        text: "Edited Text"
      }, %{})

      assert result["text"] == "Edited Text"
    end
  end
end
