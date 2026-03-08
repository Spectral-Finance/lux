defmodule Lux.Prisms.Telegram.EditMessageTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.EditMessage

  setup do
    Req.Test.stub(Lux.Telegram.EditMsgMock, fn conn ->
      Req.Test.json(conn, %{
        "ok" => true,
        "result" => %{"message_id" => 999, "text" => "edited"}
      })
    end)

    :ok
  end

  test "edits a message" do
    assert {:ok, result} =
             EditMessage.handler(
               %{chat_id: 123, message_id: 999, text: "edited", token: "t", plug: {Req.Test, Lux.Telegram.EditMsgMock}},
               []
             )

    assert result["message_id"] == 999
  end
end
