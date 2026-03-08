defmodule Lux.Integrations.TelegramTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram

  test "bot_url/1" do
    assert Telegram.bot_url("123:abc") == "https://api.telegram.org/bot123:abc"
  end

  test "file_url/2" do
    assert Telegram.file_url("123:abc", "photos/file.jpg") ==
             "https://api.telegram.org/file/bot123:abc/photos/file.jpg"
  end

  test "valid_token?/1" do
    assert Telegram.valid_token?("123456789:ABCdefGhIjKlMnOpQrStUvWxYz1234567890")
    refute Telegram.valid_token?("invalid")
    refute Telegram.valid_token?("")
    refute Telegram.valid_token?(nil)
  end
end
