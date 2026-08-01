defmodule Lux.Lenses.Telegram.Messages.SendMessageTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Telegram.Messages.SendMessage

  setup do
    Req.Test.verify_on_exit!()
    # Note: token comes from Lux.Config.telegram_bot_token() in config.
    # We mock the config in test.envrc usually or application config.
    :ok
  end

  describe "focus/2" do
    test "successfully sends a message" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert String.ends_with?(conn.request_path, "/sendMessage")
        
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["chat_id"] == "12345"
        assert params["text"] == "Hello World"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => %{
            "message_id" => 1,
            "text" => "Hello World"
          }
        }))
      end)

      assert {:ok, result} = SendMessage.focus(%{
        chat_id: "12345",
        text: "Hello World"
      }, %{})

      assert result["message_id"] == 1
      assert result["text"] == "Hello World"
    end

    test "handles Telegram API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "ok" => false,
          "error_code" => 400,
          "description" => "Bad Request: chat not found"
        }))
      end)

      assert {:error, %{"ok" => false, "description" => "Bad Request: chat not found"}} = SendMessage.focus(%{
        chat_id: "invalid_chat",
        text: "Hello"
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = SendMessage.view()
      assert lens.schema.required == ["chat_id", "text"]
    end
  end
end
