defmodule Lux.Integrations.Telegram.WebhookTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Telegram.Webhook

  describe "valid_secret_token?/2" do
    test "accepts matching Telegram webhook secret token" do
      headers = [{"X-Telegram-Bot-Api-Secret-Token", "secret-token"}]

      assert Webhook.valid_secret_token?(headers, "secret-token")
    end

    test "rejects missing and mismatched webhook secret tokens" do
      refute Webhook.valid_secret_token?([], "secret-token")

      refute Webhook.valid_secret_token?(
               [{"X-Telegram-Bot-Api-Secret-Token", "wrong-token"}],
               "secret-token"
             )
    end
  end

  describe "parse_update/1" do
    test "accepts decoded updates and JSON strings" do
      update = %{"update_id" => 123, "message" => %{"text" => "hello"}}

      assert Webhook.parse_update(update) == {:ok, update}
      assert Webhook.parse_update(Jason.encode!(update)) == {:ok, update}
    end

    test "rejects malformed update payloads" do
      assert {:error, _error} = Webhook.parse_update("{")
      assert Webhook.parse_update(["not", "a", "map"]) == {:error, :invalid_update}
    end
  end

  describe "classify_update/1" do
    test "classifies common Telegram update types" do
      assert Webhook.classify_update(%{"message" => %{}}) == :message
      assert Webhook.classify_update(%{"edited_message" => %{}}) == :edited_message
      assert Webhook.classify_update(%{"callback_query" => %{}}) == :callback_query
      assert Webhook.classify_update(%{"inline_query" => %{}}) == :inline_query
      assert Webhook.classify_update(%{"chosen_inline_result" => %{}}) == :chosen_inline_result
      assert Webhook.classify_update(%{"poll" => %{}}) == :unknown
    end
  end
end
