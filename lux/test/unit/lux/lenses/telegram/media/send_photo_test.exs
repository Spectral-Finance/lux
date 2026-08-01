defmodule Lux.Lenses.Telegram.Media.SendPhotoTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Media.SendPhoto

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully sends a photo" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendPhoto")
        
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "photo" => [%{"file_id" => "AgADBA"}]
          }
        }))
      end)

      assert {:ok, result} = SendPhoto.focus(%{
        chat_id: "12345",
        photo: "https://example.com/photo.jpg"
      }, %{})

      assert result["message_id"] == 1
    end
  end
end
