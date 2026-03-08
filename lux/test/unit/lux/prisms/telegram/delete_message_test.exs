defmodule Lux.Prisms.Telegram.DeleteMessageTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.DeleteMessage

  setup do
    Req.Test.stub(Lux.Telegram.DelMsgMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => true})
    end)

    :ok
  end

  test "deletes a message" do
    assert {:ok, true} =
             DeleteMessage.handler(
               %{chat_id: 123, message_id: 999, token: "t", plug: {Req.Test, Lux.Telegram.DelMsgMock}},
               []
             )
  end
end
