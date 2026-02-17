# Lines 1-4 of lux/test/integrations/telegram/client_test.exs
defmodule Lux.Integrations.Telegram.ClientTest do
  use ExUnit.Case, async: true
  import ExUnit.Assertions

  alias Lux.Integrations.Telegram.Client

  test "sends a message" do
    response = Client.request(:post, "/sendMessage", token: "your_bot_token", json: %{chat_id: 123_456_789, text: "Hello!"})
    assert {:ok, %{"ok" => true, "result" => %{"message_id" => _}}} = response
  end

  test "copies a message" do
    response = Client.request(:post, "/copyMessage", token: "your_bot_token", json: %{chat_id: 123_456_789, from_chat_id: 987_654_321, message_id: 42})
    assert {:ok, %{"ok" => true, "result" => %{"message_id" => _}}} = response
  end
end

test "handles successful HTTP response" do
  response = Client.request(:get, "/getMe", token: "your_bot_token")
  assert {:ok, %{"ok" => true, "result" => %{"id" => _, "is_bot" => _, "first_name" => _, "username" => _}}} = response
end