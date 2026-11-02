defmodule Lux.Integrations.Telegram.UpdatesHandlerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.UpdatesHandler

  describe "verify_secret_token/2" do
    test "verifies correct secret token" do
      secret = "my_telegram_webhook_secret_999"
      assert UpdatesHandler.verify_secret_token(secret, secret)
    end

    test "rejects incorrect or missing secret tokens" do
      refute UpdatesHandler.verify_secret_token("wrong", "expected")
      refute UpdatesHandler.verify_secret_token(nil, "expected")
      refute UpdatesHandler.verify_secret_token("", "expected")
    end
  end

  describe "normalize_update/1" do
    test "normalizes standard text message update" do
      raw = %{
        "update_id" => 123456,
        "message" => %{
          "message_id" => 888,
          "chat" => %{"id" => 99999, "type" => "private"},
          "from" => %{"id" => 11111, "username" => "lux_user"},
          "text" => "Execute mission"
        }
      }

      event = UpdatesHandler.normalize_update(raw)
      assert event.type == :message
      assert event.update_id == 123456
      assert event.message_id == 888
      assert event.chat_id == 99999
      assert event.from_username == "lux_user"
      assert event.text == "Execute mission"
    end

    test "normalizes callback query update" do
      raw = %{
        "update_id" => 123457,
        "callback_query" => %{
          "id" => "cb_1",
          "from" => %{"id" => 22222},
          "message" => %{"message_id" => 900, "chat" => %{"id" => 99999}},
          "data" => "button_action_confirm"
        }
      }

      event = UpdatesHandler.normalize_update(raw)
      assert event.type == :callback_query
      assert event.query_id == "cb_1"
      assert event.data == "button_action_confirm"
    end
  end
end
