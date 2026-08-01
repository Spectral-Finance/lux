defmodule Lux.Lenses.Telegram.Media.SendDocumentTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Media.SendDocument

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sends a document" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendDocument")
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "document" => %{"file_id" => "BQADBA"}
          }
        }))
      end)

      assert {:ok, result} = SendDocument.focus(%{
        chat_id: "12345",
        document: "https://example.com/doc.pdf"
      }, %{})

      assert result["message_id"] == 1
    end
  end
end
