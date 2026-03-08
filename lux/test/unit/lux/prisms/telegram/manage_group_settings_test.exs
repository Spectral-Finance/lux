defmodule Lux.Prisms.Telegram.ManageGroupSettingsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Telegram.ManageGroupSettings

  setup do
    Req.Test.stub(Lux.Telegram.SettingsMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => true})
    end)

    Req.Test.stub(Lux.Telegram.GetChatMock, fn conn ->
      Req.Test.json(conn, %{"ok" => true, "result" => %{
        "id" => -100123, "type" => "supergroup", "title" => "Test Group",
        "description" => "A test group", "slow_mode_delay" => 0
      }})
    end)
    :ok
  end

  test "set_title" do
    assert {:ok, %{result: true, action: "set_title"}} =
      ManageGroupSettings.handler(%{action: "set_title", chat_id: -100123, title: "New Title", token: "t", plug: {Req.Test, Lux.Telegram.SettingsMock}}, nil)
  end

  test "set_description" do
    assert {:ok, %{result: true, action: "set_description"}} =
      ManageGroupSettings.handler(%{action: "set_description", chat_id: -100123, description: "New Desc", token: "t", plug: {Req.Test, Lux.Telegram.SettingsMock}}, nil)
  end

  test "set_permissions" do
    assert {:ok, %{result: true, action: "set_permissions"}} =
      ManageGroupSettings.handler(%{action: "set_permissions", chat_id: -100123, permissions: %{can_send_messages: true}, token: "t", plug: {Req.Test, Lux.Telegram.SettingsMock}}, nil)
  end

  test "set_slow_mode" do
    assert {:ok, %{result: true, action: "set_slow_mode"}} =
      ManageGroupSettings.handler(%{action: "set_slow_mode", chat_id: -100123, slow_mode_delay: 30, token: "t", plug: {Req.Test, Lux.Telegram.SettingsMock}}, nil)
  end

  test "pin_message" do
    assert {:ok, %{result: true, action: "pin_message"}} =
      ManageGroupSettings.handler(%{action: "pin_message", chat_id: -100123, message_id: 42, token: "t", plug: {Req.Test, Lux.Telegram.SettingsMock}}, nil)
  end

  test "unpin_all" do
    assert {:ok, %{result: true, action: "unpin_all"}} =
      ManageGroupSettings.handler(%{action: "unpin_all", chat_id: -100123, token: "t", plug: {Req.Test, Lux.Telegram.SettingsMock}}, nil)
  end

  test "get_chat" do
    assert {:ok, %{result: %{"title" => "Test Group"}, action: "get_chat"}} =
      ManageGroupSettings.handler(%{action: "get_chat", chat_id: -100123, token: "t", plug: {Req.Test, Lux.Telegram.GetChatMock}}, nil)
  end
end
