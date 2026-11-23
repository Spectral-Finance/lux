defmodule Lux.Prisms.Telegram.BotTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Telegram.Bot.DeleteWebhook
  alias Lux.Prisms.Telegram.Bot.GetMe
  alias Lux.Prisms.Telegram.Bot.GetUpdates
  alias Lux.Prisms.Telegram.Bot.GetWebhookInfo
  alias Lux.Prisms.Telegram.Bot.SetWebhook

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "GetMe.handler/2" do
    test "returns the bot profile on success" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/bottest_telegram_bot_token/getMe"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "id" => 123_456_789,
              "is_bot" => true,
              "first_name" => "LuxBot",
              "username" => "lux_bot",
              "can_join_groups" => true,
              "can_read_all_group_messages" => false,
              "supports_inline_queries" => true
            }
          })
        )
      end)

      assert {:ok,
              %{
                id: 123_456_789,
                is_bot: true,
                first_name: "LuxBot",
                username: "lux_bot",
                can_join_groups: true,
                can_read_all_group_messages: false,
                supports_inline_queries: true
              }} =
               GetMe.handler(%{}, @agent_ctx)
    end

    test "handles authentication error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          401,
          Jason.encode!(%{"ok" => false, "error_code" => 401, "description" => "Unauthorized"})
        )
      end)

      # The client maps HTTP 401 to {:error, :invalid_token} before the prism
      # sees the response body, so the prism surfaces that atom.
      assert {:error, "Failed to get bot info: :invalid_token"} =
               GetMe.handler(%{}, @agent_ctx)
    end

    test "exposes a valid prism schema" do
      prism = GetMe.view()
      assert prism.name == "Get Telegram Bot Info"
      assert prism.input_schema.required == []
      assert prism.output_schema.required == ["id", "is_bot", "first_name"]
    end
  end

  describe "GetUpdates.handler/2" do
    test "returns updates and a count" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_telegram_bot_token/getUpdates"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["offset"] == 101
        assert decoded["allowed_updates"] == ["message"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => [
              %{
                "update_id" => 101,
                "message" => %{"message_id" => 1, "text" => "hi", "chat" => %{"id" => 42}}
              }
            ]
          })
        )
      end)

      assert {:ok, %{updates: [update], count: 1}} =
               GetUpdates.handler(%{offset: 101, allowed_updates: ["message"]}, @agent_ctx)

      assert update["update_id"] == 101
      assert get_in(update, ["message", "text"]) == "hi"
    end

    test "returns an empty list when there are no updates" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => []}))
      end)

      assert {:ok, %{updates: [], count: 0}} = GetUpdates.handler(%{}, @agent_ctx)
    end

    test "handles API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          409,
          Jason.encode!(%{"ok" => false, "description" => "Conflict: can't use getUpdates"})
        )
      end)

      assert {:error, "Failed to get updates: Conflict: can't use getUpdates (HTTP 409)"} =
               GetUpdates.handler(%{}, @agent_ctx)
    end

    test "exposes a valid prism schema" do
      prism = GetUpdates.view()
      assert prism.name == "Get Telegram Updates"
      assert prism.output_schema.required == ["updates", "count"]
    end
  end

  describe "SetWebhook.handler/2" do
    test "sets a webhook successfully" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_telegram_bot_token/setWebhook"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["url"] == "https://example.com/telegram/webhook"
        assert decoded["allowed_updates"] == ["message", "callback_query"]
        assert decoded["drop_pending_updates"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{webhook_set: true, url: "https://example.com/telegram/webhook"}} =
               SetWebhook.handler(
                 %{
                   url: "https://example.com/telegram/webhook",
                   allowed_updates: ["message", "callback_query"],
                   drop_pending_updates: true
                 },
                 @agent_ctx
               )
    end

    test "requires a url" do
      assert {:error, "Missing or invalid url"} = SetWebhook.handler(%{}, @agent_ctx)
    end

    test "handles API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{"ok" => false, "description" => "Bad Request: bad webhook url"})
        )
      end)

      assert {:error, "Failed to set webhook: Bad Request: bad webhook url (HTTP 400)"} =
               SetWebhook.handler(%{url: "http://insecure.example.com"}, @agent_ctx)
    end

    test "exposes a valid prism schema" do
      prism = SetWebhook.view()
      assert prism.name == "Set Telegram Webhook"
      assert prism.input_schema.required == ["url"]
      assert prism.output_schema.required == ["webhook_set", "url"]
    end
  end

  describe "DeleteWebhook.handler/2" do
    test "deletes a webhook successfully" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_telegram_bot_token/deleteWebhook"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["drop_pending_updates"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end)

      assert {:ok, %{webhook_deleted: true}} =
               DeleteWebhook.handler(%{drop_pending_updates: true}, @agent_ctx)
    end

    test "handles API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{"ok" => false, "description" => "Bad Request: no webhook"})
        )
      end)

      assert {:error, "Failed to delete webhook: Bad Request: no webhook (HTTP 400)"} =
               DeleteWebhook.handler(%{}, @agent_ctx)
    end

    test "exposes a valid prism schema" do
      prism = DeleteWebhook.view()
      assert prism.name == "Delete Telegram Webhook"
      assert prism.output_schema.required == ["webhook_deleted"]
    end
  end

  describe "GetWebhookInfo.handler/2" do
    test "returns webhook info when a webhook is configured" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/bottest_telegram_bot_token/getWebhookInfo"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "url" => "https://example.com/telegram/webhook",
              "has_custom_certificate" => false,
              "pending_update_count" => 3,
              "max_connections" => 40,
              "allowed_updates" => ["message"]
            }
          })
        )
      end)

      assert {:ok,
              %{
                url: "https://example.com/telegram/webhook",
                has_custom_certificate: false,
                pending_update_count: 3,
                max_connections: 40,
                allowed_updates: ["message"]
              }} =
               GetWebhookInfo.handler(%{}, @agent_ctx)
    end

    test "returns empty url when no webhook is set" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "ok" => true,
            "result" => %{
              "url" => "",
              "has_custom_certificate" => false,
              "pending_update_count" => 0
            }
          })
        )
      end)

      assert {:ok, %{url: "", pending_update_count: 0}} =
               GetWebhookInfo.handler(%{}, @agent_ctx)
    end

    test "handles API error" do
      Req.Test.expect(TelegramClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          401,
          Jason.encode!(%{"ok" => false, "error_code" => 401, "description" => "Unauthorized"})
        )
      end)

      # The client maps HTTP 401 to {:error, :invalid_token} before the prism
      # sees the response body, so the prism surfaces that atom.
      assert {:error, "Failed to get webhook info: :invalid_token"} =
               GetWebhookInfo.handler(%{}, @agent_ctx)
    end

    test "exposes a valid prism schema" do
      prism = GetWebhookInfo.view()
      assert prism.name == "Get Telegram Webhook Info"
      assert prism.output_schema.required == ["url", "has_custom_certificate", "pending_update_count"]
    end
  end
end