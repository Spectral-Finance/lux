defmodule Lux.Integrations.Telegram.TokenManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Client

  test "TokenManager should handle token retrieval" do
    assert Client.request(:get, "/getMe", token: "your_bot_token") == {:ok, %{"ok" => true}}
  end
end

test "TokenManager should store and retrieve a token" do
  token = "your_bot_token"
  assert Client.store_token(token) == :ok
  assert Client.retrieve_token() == {:ok, token}
end