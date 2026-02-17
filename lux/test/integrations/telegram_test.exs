# Lines 1-5 of lux/test/integrations/telegram_test.exs
defmodule Lux.Integrations.Telegram.Test do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Client

  import ExUnit.Assertions

  test "sends a message" do
    response = Client.request(:post, "/sendMessage", token: "your_bot_token", json: %{chat_id: 123_456_789, text: "Hello!"})
    assert {:ok, %{"ok" => true}} = response
  end

  test "copies a message" do
    response = Client.request(:post, "/copyMessage", token: "your_bot_token", json: %{chat_id: 123_456_789, from_chat_id: 987_654_321, message_id: 42})
    assert {:ok, %{"ok" => true}} = response
  end
end

test "retrieves successful bot updates" do
  response = Client.request(:get, "/getUpdates", token: "your_bot_token")
  assert {:ok, %{"ok" => true}} = response
end