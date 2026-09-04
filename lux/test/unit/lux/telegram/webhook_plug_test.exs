defmodule Lux.Telegram.WebhookPlugTest do
  use UnitAPICase, async: false

  alias Lux.Telegram.WebhookPlug

  defmodule DummyHandler do
    def handle_signal(signal) do
      send(self(), {:dummy_handled, signal})
      :ok
    end
  end

  describe "init/1" do
    test "initializes with explicit secret_token and handler" do
      opts = WebhookPlug.init(secret_token: "my_secret", handler: self())
      assert opts.secret_token == "my_secret"
      assert opts.handler == self()
    end

    test "initializes with string key secret_token" do
      opts = WebhookPlug.init(%{"secret_token" => "string_secret"})
      assert opts.secret_token == "string_secret"
    end

    test "falls back to config or env for secret token" do
      orig_keys = Application.get_env(:lux, :api_keys, [])
      try do
        Application.put_env(:lux, :api_keys, [telegram_secret: "cfg_secret"])
        opts = WebhookPlug.init(%{})
        assert opts.secret_token == "cfg_secret"

        Application.put_env(:lux, :api_keys, [])
        opts_nil = WebhookPlug.init(%{})
        assert opts_nil.secret_token == nil
      after
        Application.put_env(:lux, :api_keys, orig_keys)
      end
    end
  end

  describe "call/2 authorization" do
    test "allows request when secret_token is nil or empty" do
      opts = WebhookPlug.init(secret_token: nil, handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 100}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 200
      assert_receive {:telegram_update, signal}
      assert signal.payload["update_id"] == 100
    end

    test "allows request when secret_token matches X-Telegram-Bot-Api-Secret-Token header" do
      opts = WebhookPlug.init(secret_token: "secret_123", handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 101}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Plug.Conn.put_req_header("x-telegram-bot-api-secret-token", "secret_123")
        |> WebhookPlug.call(opts)

      assert conn.status == 200
      assert_receive {:telegram_update, signal}
      assert signal.payload["update_id"] == 101
    end

    test "rejects request with 401 when secret_token header is invalid or missing" do
      opts = WebhookPlug.init(secret_token: "secret_123", handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 102}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Plug.Conn.put_req_header("x-telegram-bot-api-secret-token", "wrong_secret")
        |> WebhookPlug.call(opts)

      assert conn.status == 401
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Unauthorized", "status" => "error"}
    end
  end

  describe "payload validation and 400 Bad Request handling" do
    test "rejects request with 400 when body is malformed JSON" do
      opts = WebhookPlug.init(handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", "{invalid-json-payload")
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 400
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Malformed JSON", "status" => "error"}
      refute_receive {:telegram_update, _}
    end

    test "rejects request with 400 when body is empty" do
      opts = WebhookPlug.init(handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", "")
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 400
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Empty request body", "status" => "error"}
      refute_receive {:telegram_update, _}
    end

    test "rejects request with 400 when payload is missing required update_id" do
      opts = WebhookPlug.init(handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"message" => %{"text" => "no update id"}}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 400
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid update payload", "status" => "error"}
      refute_receive {:telegram_update, _}
    end

    test "rejects request with 400 when JSON body is a non-map list or scalar" do
      opts = WebhookPlug.init(handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!([1, 2, 3]))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 400
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid payload", "status" => "error"}
      refute_receive {:telegram_update, _}
    end
  end

  describe "dispatch_signal with different handlers" do
    test "dispatches signal to function handler" do
      test_pid = self()
      handler_fn = fn sig -> send(test_pid, {:fn_handled, sig}) end
      opts = WebhookPlug.init(handler: handler_fn)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 201}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 200
      assert_receive {:fn_handled, signal}
      assert signal.payload["update_id"] == 201
    end

    test "handles exceptions in function handler gracefully by returning 500" do
      failing_fn = fn _sig -> raise "Handler crash test" end
      opts = WebhookPlug.init(handler: failing_fn)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 202}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body)["status"] == "error"
    end

    test "handles function handler returning {:error, reason} with 500" do
      failing_fn = fn _sig -> {:error, :database_offline} end
      opts = WebhookPlug.init(handler: failing_fn)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 202}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body)["status"] == "error"
    end

    test "handles function handler returning :error with 500" do
      failing_fn = fn _sig -> :error end
      opts = WebhookPlug.init(handler: failing_fn)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 202}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body)["status"] == "error"
    end

    test "dispatches signal to module handler" do
      opts = WebhookPlug.init(handler: DummyHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 203}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 200
      assert_receive {:dummy_handled, signal}
      assert signal.payload["update_id"] == 203
    end

    test "parses payload pre-populated in body_params" do
      opts = WebhookPlug.init(handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook")
        |> Map.put(:body_params, %{"update_id" => 301, "message" => %{"text" => "preparsed"}})
        |> WebhookPlug.call(opts)

      assert conn.status == 200
      assert_receive {:telegram_update, signal}
      assert signal.payload["update_id"] == 301
    end
  end

  describe "WebhookPlug delegations" do
    test "delegates set_webhook, delete_webhook, and get_webhook_info to Webhook" do
      plug = fn conn ->
        cond do
          conn.request_path =~ "/setWebhook" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))

          conn.request_path =~ "/deleteWebhook" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))

          conn.request_path =~ "/getWebhookInfo" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => %{"url" => "https://example.com/webhook"}}))
        end
      end

      opts = [token: "tok", plug: plug]
      assert {:ok, _} = WebhookPlug.set_webhook("https://example.com/webhook", opts)
      assert {:ok, _} = WebhookPlug.delete_webhook(opts)
      assert {:ok, _} = WebhookPlug.get_webhook_info(opts)
    end
  end

  describe "Lux.Telegram.Webhook direct module functions and body parser edge cases" do
    test "direct Webhook helper functions" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      opts = [token: "tok", plug: plug]
      assert {:ok, _} = Lux.Telegram.Webhook.set_webhook("https://example.com/wh", opts)
      assert {:ok, _} = Lux.Telegram.Webhook.delete_webhook(opts)
      assert {:ok, _} = Lux.Telegram.Webhook.get_webhook_info(opts)
    end

    test "parses body_params with atom key :update_id" do
      opts = Lux.Telegram.Webhook.init(handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook")
        |> Map.put(:body_params, %{update_id: 888, message: %{text: "atom key"}})
        |> Lux.Telegram.Webhook.call(opts)

      assert conn.status == 200
      assert_receive {:telegram_update, signal}
      assert signal.payload[:update_id] == 888 || signal.payload["update_id"] == 888
    end

    test "returns 400 for empty JSON object" do
      opts = Lux.Telegram.Webhook.init(handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", "{}")
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(opts)

      assert conn.status == 400
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid payload", "status" => "error"}
    end
  end

  describe "webhook edge cases and fallbacks" do
    test "secret_token_valid? with empty string" do
      opts = Lux.Telegram.Webhook.init(secret_token: "", handler: self())
      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 901}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(opts)
      assert conn.status == 200
    end

    test "parse_payload with non-empty map body_params lacking update_id" do
      opts = Lux.Telegram.Webhook.init(handler: self())
      conn =
        :post
        |> Plug.Test.conn("/webhook")
        |> Map.put(:body_params, %{"other" => "val"})
        |> Lux.Telegram.Webhook.call(opts)
      assert conn.status == 400
    end

    test "dispatch_signal when handler module has no callbacks" do
      defmodule NoCallbacksHandler do
      end
      opts = Lux.Telegram.Webhook.init(handler: NoCallbacksHandler)
      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 902}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(opts)
      assert conn.status == 200
    end

    test "dispatch_signal when handler is nil" do
      opts = %{secret_token: nil, handler: nil}
      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 903}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(opts)
      assert conn.status == 200
    end

    test "direct Webhook helper functions" do
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => true}))
      end

      opts = [token: "tok", plug: plug]
      assert {:ok, _} = Lux.Telegram.Webhook.set_webhook("https://example.com/wh", opts)
      assert {:ok, _} = Lux.Telegram.Webhook.delete_webhook(opts)
      assert {:ok, _} = Lux.Telegram.Webhook.get_webhook_info(opts)
    end

    test "parses body_params with atom key :update_id" do
      opts = Lux.Telegram.Webhook.init(handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook")
        |> Map.put(:body_params, %{update_id: 888, message: %{text: "atom key"}})
        |> Lux.Telegram.Webhook.call(opts)

      assert conn.status == 200
      assert_receive {:telegram_update, signal}
      assert signal.payload[:update_id] == 888 || signal.payload["update_id"] == 888
    end

    test "returns 400 for empty JSON object and JSON array" do
      opts = Lux.Telegram.Webhook.init(handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", "{}")
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(opts)

      assert conn.status == 400
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid payload", "status" => "error"}

      conn_arr =
        :post
        |> Plug.Test.conn("/webhook", "[1, 2]")
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(opts)

      assert conn_arr.status == 400
      assert conn_arr.halted
      assert Jason.decode!(conn_arr.resp_body) == %{"error" => "Invalid payload", "status" => "error"}
    end
  end

  describe "webhook plug edge cases and full branch coverage" do
    test "secret_token_valid? with empty string" do
      opts = Lux.Telegram.Webhook.init(secret_token: "", handler: self())
      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 901}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(opts)
      assert conn.status == 200
    end

    test "parse_payload with non-empty map body_params lacking update_id" do
      opts = Lux.Telegram.Webhook.init(handler: self())
      conn =
        :post
        |> Plug.Test.conn("/webhook")
        |> Map.put(:body_params, %{"other" => "val"})
        |> Lux.Telegram.Webhook.call(opts)
      assert conn.status == 400
      assert conn.halted
    end

    defmodule ModuleUpdateHandler do
      def handle_update(signal) do
        send(self(), {:module_update_handled, signal})
        :ok
      end
    end

    test "dispatch_signal when handler module implements handle_update/1" do
      opts = Lux.Telegram.Webhook.init(handler: ModuleUpdateHandler)
      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 905}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(opts)
      assert conn.status == 200
      assert_receive {:module_update_handled, _}
    end

    test "dispatch_signal when handler throws, exits, or crashes" do
      # Throw
      throw_opts = Lux.Telegram.Webhook.init(handler: fn _sig -> throw(:webhook_throw) end)
      conn_throw =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 906}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(throw_opts)
      assert conn_throw.status == 500

      # Exit
      exit_opts = Lux.Telegram.Webhook.init(handler: fn _sig -> exit(:webhook_exit) end)
      conn_exit =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 907}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Lux.Telegram.Webhook.call(exit_opts)
      assert conn_exit.status == 500
    end

    test "fetch_config_secret_token fallback" do
      opts = Lux.Telegram.Webhook.init(%{})
      assert opts.secret_token == nil || is_binary(opts.secret_token)
    end
  end
end


