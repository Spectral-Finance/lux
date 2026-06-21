defmodule Lux.Integrations.Telegram.WebhookTest do
  use UnitAPICase, async: false

  alias Lux.Integrations.Telegram.Webhook

  @bot_token "test_bot_token"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "set/2" do
    test "configures webhook with secret token and allowed updates" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_bot_token/setWebhook"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["url"] == "https://example.com/telegram"
        assert payload["secret_token"] == "secret"
        assert payload["allowed_updates"] == ["message", "callback_query"]
        refute Map.has_key?(payload, "token")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{"result" => true}} =
               Webhook.set("https://example.com/telegram", %{
                 token: @bot_token,
                 secret_token: "secret",
                 allowed_updates: ["message", "callback_query"]
               })
    end
  end

  describe "verify_secret_token/2" do
    test "checks secret token headers with constant-time compare" do
      headers = [{"x-telegram-bot-api-secret-token", "secret"}]

      assert Webhook.verify_secret_token(headers, "secret")
      refute Webhook.verify_secret_token(headers, "wrong")
      refute Webhook.verify_secret_token([], "secret")
      refute Webhook.verify_secret_token(headers, "")
    end
  end

  describe "update helpers" do
    test "classifies update type and extracts chat id" do
      update = %{
        "update_id" => 1,
        "callback_query" => %{
          "id" => "query-1",
          "message" => %{"chat" => %{"id" => 123}}
        }
      }

      assert Webhook.update_type(update) == :callback_query
      assert Webhook.chat_id(update) == 123
      assert Webhook.update_type(%{"unexpected" => true}) == :unknown
      assert Webhook.chat_id(%{"unexpected" => true}) == nil
    end
  end
end
