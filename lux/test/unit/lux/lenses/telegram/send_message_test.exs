defmodule Lux.Lenses.Telegram.Messages.SendMessageTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Telegram.Messages.SendMessage

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "sends text message via lens" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.contains?(conn.request_path, "/sendMessage")

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["chat_id"] == "12345"
        assert decoded["text"] == "Hello from Telegram Lens!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "message_id" => 777,
              "chat" => %{"id" => 12345},
              "text" => decoded["text"],
              "date" => 1700000000
            }
          })
        )
      end)

      assert {:ok, result} =
               SendMessage.focus(%{"chat_id" => "12345", "text" => "Hello from Telegram Lens!"}, %{})

      assert result.message_id == 777
      assert result.text == "Hello from Telegram Lens!"
    end

    test "validates required parameters" do
      assert {:error, errors} = SendMessage.focus(%{})
      assert is_list(errors)
    end
  end
end
