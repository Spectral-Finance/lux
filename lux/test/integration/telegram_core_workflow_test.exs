defmodule Lux.Integrations.TelegramCoreWorkflowTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.Telegram.Client
  alias Lux.Integrations.Telegram.Webhook

  @bot_token "test_bot_token"

  setup do
    Application.put_env(:lux, Client, plug: {Req.Test, TelegramWorkflowMock})
    Req.Test.verify_on_exit!()
    :ok
  end

  test "configures webhook, parses update, and runs queued message operations" do
    Req.Test.stub(TelegramWorkflowMock, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = if body == "", do: %{}, else: Jason.decode!(body)

      response =
        case conn.request_path do
          "/bot#{@bot_token}/setWebhook" ->
            assert payload["secret_token"] == "secret"
            %{"ok" => true, "result" => true}

          "/bot#{@bot_token}/sendMessage" ->
            assert payload["reply_markup"]["inline_keyboard"] == [
                     [%{"text" => "Open", "url" => "https://lux.dev"}]
                   ]

            %{"ok" => true, "result" => %{"message_id" => 10}}

          "/bot#{@bot_token}/editMessageText" ->
            assert payload["message_id"] == 10
            %{"ok" => true, "result" => %{"message_id" => 10, "text" => payload["text"]}}

          "/bot#{@bot_token}/deleteMessage" ->
            assert payload["message_id"] == 10
            %{"ok" => true, "result" => true}
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(response))
    end)

    assert {:ok, %{"result" => true}} =
             Webhook.set("https://example.com/telegram", %{
               token: @bot_token,
               secret_token: "secret",
               allowed_updates: ["message", "callback_query"]
             })

    update = %{
      "message" => %{
        "message_id" => 9,
        "chat" => %{"id" => 123},
        "text" => "/start"
      }
    }

    assert Webhook.update_type(update) == :message
    assert Webhook.chat_id(update) == 123

    assert {:ok,
            [
              %{"result" => %{"message_id" => 10}},
              %{"result" => %{"message_id" => 10}},
              %{"result" => true}
            ]} =
             Client.request_many(
               [
                 %{
                   method: :post,
                   path: "/sendMessage",
                   json: %{
                     chat_id: 123,
                     text: "Welcome",
                     reply_markup: %{
                       inline_keyboard: [[%{text: "Open", url: "https://lux.dev"}]]
                     }
                   }
                 },
                 %{
                   method: :post,
                   path: "/editMessageText",
                   json: %{chat_id: 123, message_id: 10, text: "Ready"}
                 },
                 %{method: :post, path: "/deleteMessage", json: %{chat_id: 123, message_id: 10}}
               ],
               token: @bot_token,
               queue_interval_ms: 0
             )
  end
end
