defmodule Lux.Integrations.TelegramTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Telegram
  alias Lux.Lens

  describe "add_auth_url/1" do
    test "injects bot token into the lens url" do
      System.put_env("TELEGRAM_BOT_TOKEN", "mock_bot_token")
      
      lens = %Lens{
        url: "https://api.telegram.org/bot<token>/getMe"
      }
      
      authenticated_lens = Telegram.add_auth_url(lens)
      
      assert authenticated_lens.url == "https://api.telegram.org/botmock_bot_token/getMe"
    end
  end
end
