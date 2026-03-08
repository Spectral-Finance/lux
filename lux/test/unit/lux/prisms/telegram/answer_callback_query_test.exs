defmodule Lux.Prisms.Telegram.AnswerCallbackQueryTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.AnswerCallbackQuery

  setup do
    Req.Test.stub(Lux.Telegram.CallbackMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => true})
    end)

    :ok
  end

  test "answers callback query" do
    assert {:ok, true} =
             AnswerCallbackQuery.handler(
               %{callback_query_id: "cb1", text: "Done!", token: "t", plug: {Req.Test, Lux.Telegram.CallbackMock}},
               []
             )
  end

  test "answers with alert" do
    assert {:ok, true} =
             AnswerCallbackQuery.handler(
               %{callback_query_id: "cb2", text: "Error!", show_alert: true, token: "t", plug: {Req.Test, Lux.Telegram.CallbackMock}},
               []
             )
  end
end
