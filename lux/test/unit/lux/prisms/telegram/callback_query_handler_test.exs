defmodule Lux.Prisms.Telegram.CallbackQueryHandlerTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.CallbackQueryHandler

  setup do
    Req.Test.stub(Lux.Telegram.CallbackMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => true})
    end)
    :ok
  end

  test "answer callback query" do
    {:ok, %{"result" => true}} = CallbackQueryHandler.handler(%{
      action: "answer",
      token: "t",
      callback_query_id: "123",
      text: "Done!",
      show_alert: false,
      plug: {Req.Test, Lux.Telegram.CallbackMock}
    }, nil)
  end

  test "parse colon-separated callback data" do
    {:ok, result} = CallbackQueryHandler.parse_callback_data(%{callback_data: "vote:option:3"})
    assert result.action == "vote"
    assert result.args == ["option", "3"]
    assert result.format == :colon
  end

  test "parse pipe-separated callback data with named params" do
    {:ok, result} = CallbackQueryHandler.parse_callback_data(%{callback_data: "settings|lang=en|theme=dark"})
    assert result.action == "settings"
    assert result.params["lang"] == "en"
    assert result.params["theme"] == "dark"
    assert result.format == :pipe
  end

  test "parse plain callback data" do
    {:ok, result} = CallbackQueryHandler.parse_callback_data(%{callback_data: "cancel"})
    assert result.action == "cancel"
    assert result.format == :plain
  end

  test "edit callback message" do
    {:ok, %{"result" => true}} = CallbackQueryHandler.handler(%{
      action: "edit_message",
      token: "t",
      chat_id: -100,
      message_id: 456,
      text: "Updated!",
      plug: {Req.Test, Lux.Telegram.CallbackMock}
    }, nil)
  end
end
