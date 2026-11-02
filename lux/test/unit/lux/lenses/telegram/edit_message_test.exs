defmodule Lux.Lenses.Telegram.Messages.EditMessageTextTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.Messages.EditMessageText

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "edits message text via lens" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/editMessageText")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["message_id"] == 777
        assert decoded["text"] == "Updated text"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "message_id" => 777,
              "text" => "Updated text",
              "edit_date" => 1700000050
            }
          })
        )
      end)

      assert {:ok, result} =
               EditMessageText.focus(
                 %{"chat_id" => "12345", "message_id" => 777, "text" => "Updated text"},
                 %{}
               )

      assert result.message_id == 777
      assert result.text == "Updated text"
    end
  end
end
