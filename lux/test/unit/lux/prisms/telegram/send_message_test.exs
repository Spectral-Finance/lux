defmodule Lux.Prisms.Telegram.SendMessageTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.SendMessage

  setup do
    Req.Test.stub(Lux.Telegram.SendMsgMock, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      params = Jason.decode!(body)

      Req.Test.json(conn, %{
        "ok" => true,
        "result" => %{
          "message_id" => 999,
          "chat" => %{"id" => params["chat_id"]},
          "text" => params["text"]
        }
      })
    end)

    :ok
  end

  test "sends a text message" do
    assert {:ok, result} =
             SendMessage.handler(
               %{
                 chat_id: 12345,
                 text: "Hello!",
                 token: "123:abc",
                 plug: {Req.Test, Lux.Telegram.SendMsgMock}
               },
               []
             )

    assert result["message_id"] == 999
    assert result["text"] == "Hello!"
  end

  test "sends with parse mode" do
    assert {:ok, _} =
             SendMessage.handler(
               %{
                 chat_id: 12345,
                 text: "*bold*",
                 parse_mode: "Markdown",
                 token: "123:abc",
                 plug: {Req.Test, Lux.Telegram.SendMsgMock}
               },
               []
             )
  end

  test "sends with inline keyboard" do
    assert {:ok, _} =
             SendMessage.handler(
               %{
                 chat_id: 12345,
                 text: "Choose:",
                 reply_markup: %{
                   inline_keyboard: [
                     [%{text: "Option 1", callback_data: "opt1"}],
                     [%{text: "Option 2", callback_data: "opt2"}]
                   ]
                 },
                 token: "123:abc",
                 plug: {Req.Test, Lux.Telegram.SendMsgMock}
               },
               []
             )
  end
end
