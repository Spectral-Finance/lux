defmodule Lux.Telegram.AdversarialStressTest do
  use UnitAPICase, async: false
  require Logger

  alias Lux.Telegram.Webhook
  alias Lux.Telegram.WebhookPlug
  alias Lux.Telegram.Poller

  @secret_token "V3ry_S3cur3_T0k3n_#2026!"

  # ============================================================================
  # HELPER MODULE HANDLERS FOR ADVERSARIAL TESTING
  # ============================================================================

  defmodule CrashRaiseSignalHandler do
    def handle_signal(_signal), do: raise(RuntimeError, "Module handle_signal raise crash")
  end

  defmodule CrashThrowSignalHandler do
    def handle_signal(_signal), do: throw(:module_signal_throw_bomb)
  end

  defmodule CrashExitSignalHandler do
    def handle_signal(_signal), do: exit(:module_signal_kill)
  end

  defmodule ErrorTupleSignalHandler do
    def handle_signal(_signal), do: {:error, :database_connection_lost}
  end

  defmodule ErrorAtomSignalHandler do
    def handle_signal(_signal), do: :error
  end

  defmodule CrashRaiseUpdateHandler do
    def handle_update(_signal), do: raise(RuntimeError, "Module handle_update raise crash")
  end

  defmodule CrashThrowUpdateHandler do
    def handle_update(_signal), do: throw(:module_update_throw_bomb)
  end

  defmodule CrashExitUpdateHandler do
    def handle_update(_signal), do: exit(:module_update_kill)
  end

  defmodule ErrorTupleUpdateHandler do
    def handle_update(_signal), do: {:error, :upstream_timeout}
  end

  defmodule ErrorAtomUpdateHandler do
    def handle_update(_signal), do: :error
  end

  defmodule SuccessSignalHandler do
    def handle_signal(signal) do
      if pid = Process.whereis(:test_receiver) do
        send(pid, {:module_signal_ok, signal})
      end
      :ok
    end
  end

  defmodule SuccessUpdateHandler do
    def handle_update(signal) do
      if pid = Process.whereis(:test_receiver) do
        send(pid, {:module_update_ok, signal})
      end
      :ok
    end
  end

  defmodule NonHandlerModule do
    def other_function, do: :ok
  end

  # ============================================================================
  # 1. WEBHOOK R1: HANDLER FAILURE MODES (CRASHES, THROWS, EXITS, ERROR TUPLES)
  # ============================================================================

  describe "Webhook R1: Function handler failure modes return 500 and halt" do
    test "fn handler raising RuntimeError returns 500, halts, and returns JSON error" do
      handler = fn _sig -> raise RuntimeError, "Boom! Handler exploded" end
      opts = Webhook.init(handler: handler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 101}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "fn handler throwing a term returns 500, halts, and returns JSON error" do
      handler = fn _sig -> throw(:fatal_throw) end
      opts = Webhook.init(handler: handler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 102}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "fn handler calling exit/1 returns 500, halts, and returns JSON error" do
      handler = fn _sig -> exit(:killed_by_handler) end
      opts = Webhook.init(handler: handler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 103}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "fn handler returning {:error, :reason} returns 500, halts, and returns JSON error" do
      handler = fn _sig -> {:error, :invalid_state} end
      opts = Webhook.init(handler: handler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 104}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "fn handler returning :error returns 500, halts, and returns JSON error" do
      handler = fn _sig -> :error end
      opts = Webhook.init(handler: handler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 105}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end
  end

  describe "Webhook R1: Module handler failure modes return 500 and halt" do
    test "module handle_signal/1 raising an exception returns 500 and halts" do
      opts = Webhook.init(handler: CrashRaiseSignalHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 110}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "module handle_signal/1 throwing a term returns 500 and halts" do
      opts = Webhook.init(handler: CrashThrowSignalHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 111}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "module handle_signal/1 exiting returns 500 and halts" do
      opts = Webhook.init(handler: CrashExitSignalHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 112}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "module handle_signal/1 returning {:error, reason} returns 500 and halts" do
      opts = Webhook.init(handler: ErrorTupleSignalHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 113}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "module handle_signal/1 returning :error returns 500 and halts" do
      opts = Webhook.init(handler: ErrorAtomSignalHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 114}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "module handle_update/1 raising an exception returns 500 and halts" do
      opts = Webhook.init(handler: CrashRaiseUpdateHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 115}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "module handle_update/1 throwing a term returns 500 and halts" do
      opts = Webhook.init(handler: CrashThrowUpdateHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 116}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "module handle_update/1 exiting returns 500 and halts" do
      opts = Webhook.init(handler: CrashExitUpdateHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 117}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "module handle_update/1 returning {:error, reason} returns 500 and halts" do
      opts = Webhook.init(handler: ErrorTupleUpdateHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 118}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "module handle_update/1 returning :error returns 500 and halts" do
      opts = Webhook.init(handler: ErrorAtomUpdateHandler)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 119}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Webhook.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end

    test "WebhookPlug alias delegates correctly for handler crashes" do
      opts = WebhookPlug.init(handler: fn _ -> raise "Delegated plug boom" end)

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 120}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> WebhookPlug.call(opts)

      assert conn.status == 500
      assert conn.halted
      assert Jason.decode!(conn.resp_body) == %{"error" => "Handler error", "status" => "error"}
    end
  end

  # ============================================================================
  # 2. WEBHOOK INPUT VALIDATION AND AUTH STRESS TESTS
  # ============================================================================

  describe "Webhook: Malformed JSON syntax stress test" do
    @malformed_bodies [
      {"truncated json", "{\"update_id\": 100, \"message\": {"},
      {"unbalanced closing braces", "{\"update_id\": 100}}"},
      {"unbalanced array brackets", "[{\"update_id\": 100}"},
      {"illegal escape character", "{\"text\": \"illegal \\x escape\"}"},
      {"binary garbage 1", <<0, 255, 128, 64>>},
      {"binary garbage 2", <<0x80, 0x81, 0x82, 0xFF>>},
      {"trailing comma", "{\"update_id\": 100,}"},
      {"single-quoted json", "{'update_id': 100}"},
      {"unquoted keys", "{update_id: 100}"},
      {"truncated string", "{\"update_id\": 100, \"text\": \"unclosed string"},
      {"double colon", "{\"update_id\":: 100}"},
      {"null byte injection in body", "{\"update_id\": 100\0, \"text\": \"null\"}"}
    ]

    for {label, body} <- @malformed_bodies do
      @tag label: label
      test "rejects malformed JSON (#{label}) with HTTP 400 and halts" do
        opts = Webhook.init(handler: self())

        conn =
          :post
          |> Plug.Test.conn("/webhook", unquote(body))
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Webhook.call(opts)

        assert conn.status == 400, "Expected 400 for #{unquote(label)}, got #{conn.status}"
        assert conn.halted
        assert Jason.decode!(conn.resp_body) == %{"error" => "Malformed JSON", "status" => "error"}
        refute_receive {:telegram_update, _}
      end
    end
  end

  describe "Webhook: Empty and whitespace body stress test" do
    @empty_or_whitespace_bodies [
      {"empty string", ""},
      {"single space", " "},
      {"multiple spaces", "     "},
      {"newlines and tabs", "\n\t\r\n \t  "},
      {"mixed whitespace", "   \r\n \t \n  "}
    ]

    for {label, body} <- @empty_or_whitespace_bodies do
      test "rejects empty/whitespace body (#{label}) with HTTP 400 and halts" do
        opts = Webhook.init(handler: self())

        conn =
          :post
          |> Plug.Test.conn("/webhook", unquote(body))
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Webhook.call(opts)

        assert conn.status == 400
        assert conn.halted
        decoded = Jason.decode!(conn.resp_body)
        assert decoded["status"] == "error"
        assert decoded["error"] in ["Empty request body", "Malformed JSON"]
        refute_receive {:telegram_update, _}
      end
    end
  end

  describe "Webhook: Non-map JSON root types stress test" do
    @non_map_roots [
      {"empty array", Jason.encode!([])},
      {"array of integers", Jason.encode!([1, 2, 3])},
      {"array of valid update maps", Jason.encode!([%{"update_id" => 100}])},
      {"primitive positive integer", Jason.encode!(12345)},
      {"primitive zero", Jason.encode!(0)},
      {"primitive negative integer", Jason.encode!(-42)},
      {"primitive float", Jason.encode!(3.14159)},
      {"primitive string", Jason.encode!("hello world")},
      {"primitive empty string", Jason.encode!("")},
      {"primitive boolean true", Jason.encode!(true)},
      {"primitive boolean false", Jason.encode!(false)},
      {"primitive null", Jason.encode!(nil)},
      {"empty object map", Jason.encode!(%{})}
    ]

    for {label, body} <- @non_map_roots do
      test "rejects non-map/empty JSON root (#{label}) with HTTP 400 and halts" do
        opts = Webhook.init(handler: self())

        conn =
          :post
          |> Plug.Test.conn("/webhook", unquote(body))
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Webhook.call(opts)

        assert conn.status == 400
        assert conn.halted
        assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid payload", "status" => "error"}
        refute_receive {:telegram_update, _}
      end
    end
  end

  describe "Webhook: Invalid update schema maps stress test" do
    @invalid_schema_payloads [
      {"missing update_id (only message)", %{"message" => %{"text" => "hi"}}},
      {"missing update_id (empty fields)", %{"unrelated" => "value"}},
      {"update_id is string", %{"update_id" => "100"}},
      {"update_id is float", %{"update_id" => 100.5}},
      {"update_id is nil", %{"update_id" => nil}},
      {"update_id is boolean true", %{"update_id" => true}},
      {"update_id is boolean false", %{"update_id" => false}},
      {"update_id is list", %{"update_id" => [100]}},
      {"update_id is map", %{"update_id" => %{"id" => 100}}},
      {"message is string instead of object", %{"update_id" => 101, "message" => "not_an_object"}},
      {"message is integer instead of object", %{"update_id" => 102, "message" => 12345}},
      {"message is list instead of object", %{"update_id" => 103, "message" => [%{"text" => "hi"}]}},
      {"callback_query is integer", %{"update_id" => 104, "callback_query" => 999}},
      {"chat_member is boolean", %{"update_id" => 105, "chat_member" => true}},
      {"poll is string", %{"update_id" => 106, "poll" => "invalid_poll"}}
    ]

    for {label, payload} <- @invalid_schema_payloads do
      test "rejects invalid update schema (#{label}) with HTTP 400 and halts" do
        opts = Webhook.init(handler: self())

        conn =
          :post
          |> Plug.Test.conn("/webhook", Jason.encode!(unquote(Macro.escape(payload))))
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> Webhook.call(opts)

        assert conn.status == 400
        assert conn.halted
        assert Jason.decode!(conn.resp_body) == %{"error" => "Invalid update payload", "status" => "error"}
        refute_receive {:telegram_update, _}
      end
    end
  end

  describe "Webhook: Secret token authentication bypass attempts" do
    @auth_bypass_cases [
      {"missing header", nil},
      {"empty header value", ""},
      {"wrong secret token", "Wrong_Secret_Token_999"},
      {"secret with trailing space", "#{@secret_token} "},
      {"secret with leading space", " #{@secret_token}"},
      {"secret with trailing newline", "#{@secret_token}\n"},
      {"lowercase variation", String.downcase(@secret_token)},
      {"uppercase variation", String.upcase(@secret_token)},
      {"prefix match attempt", "#{@secret_token}_extra"},
      {"suffix match attempt", "pre_#{@secret_token}"},
      {"null byte appended", "#{@secret_token}\0"},
      {"sql-injection like token", "#{@secret_token}' OR '1'='1"}
    ]

    for {label, header_val} <- @auth_bypass_cases do
      test "rejects secret token bypass attempt (#{label}) with HTTP 401 and halts" do
        opts = Webhook.init(secret_token: @secret_token, handler: self())

        conn =
          :post
          |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 200, "message" => %{"text" => "hello"}}))
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> then(fn c ->
            if unquote(header_val) do
              Plug.Conn.put_req_header(c, "x-telegram-bot-api-secret-token", unquote(header_val))
            else
              c
            end
          end)
          |> Webhook.call(opts)

        assert conn.status == 401
        assert conn.halted
        assert Jason.decode!(conn.resp_body) == %{"error" => "Unauthorized", "status" => "error"}
        refute_receive {:telegram_update, _}
      end
    end

    test "accepts request when secret token matches exactly" do
      opts = Webhook.init(secret_token: @secret_token, handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 201, "message" => %{"text" => "authorized"}}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Plug.Conn.put_req_header("x-telegram-bot-api-secret-token", @secret_token)
        |> Webhook.call(opts)

      assert conn.status == 200
      refute conn.halted
      assert_receive {:telegram_update, signal}
      assert signal.payload["update_id"] == 201
    end

    test "accepts request with unicode / multibyte secret token" do
      unicode_token = "🔑_töken_2026_🔐"
      opts = Webhook.init(secret_token: unicode_token, handler: self())

      conn =
        :post
        |> Plug.Test.conn("/webhook", Jason.encode!(%{"update_id" => 202, "message" => %{"text" => "unicode auth"}}))
        |> Plug.Conn.put_req_header("content-type", "application/json")
        |> Plug.Conn.put_req_header("x-telegram-bot-api-secret-token", unicode_token)
        |> Webhook.call(opts)

      assert conn.status == 200
      assert_receive {:telegram_update, signal}
      assert signal.payload["update_id"] == 202
    end
  end

  # ============================================================================
  # 3. POLLER R1: HANDLER FAILURE MODES IN POLL_ONCE (SINGLE & MULTI-BATCH)
  # ============================================================================

  describe "Poller R1: Function handler failure modes in poll_once do not advance offset" do
    test "fn handler raising RuntimeError halts batch and preserves unadvanced offset" do
      test_pid = self()

      crashing_handler = fn signal ->
        if signal.payload["update_id"] == 302 do
          raise RuntimeError, "Explosion on 302"
        else
          send(test_pid, {:handled, signal.payload["update_id"]})
        end
      end

      updates = [
        %{"update_id" => 301, "message" => %{"text" => "msg 301"}},
        %{"update_id" => 302, "message" => %{"text" => "msg 302"}},
        %{"update_id" => 303, "message" => %{"text" => "msg 303"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: crashing_handler,
          autostart: false,
          offset: 300
        })

      assert {:error, {:handler_error, {:handler_exception, %RuntimeError{message: "Explosion on 302"}}}} =
               Poller.poll_once(poller)

      # 301 was processed, so offset reached 302. 302 crashed, so offset MUST NOT be 303 or 304!
      assert Poller.get_offset(poller) == 302

      assert_receive {:handled, 301}
      refute_receive {:handled, 302}
      refute_receive {:handled, 303}

      Poller.stop(poller)
    end

    test "fn handler throwing a term halts batch and preserves unadvanced offset" do
      test_pid = self()

      throwing_handler = fn signal ->
        if signal.payload["update_id"] == 402 do
          throw(:throw_bomb)
        else
          send(test_pid, {:handled, signal.payload["update_id"]})
        end
      end

      updates = [
        %{"update_id" => 401, "message" => %{"text" => "msg 401"}},
        %{"update_id" => 402, "message" => %{"text" => "msg 402"}},
        %{"update_id" => 403, "message" => %{"text" => "msg 403"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: throwing_handler,
          autostart: false,
          offset: 400
        })

      assert {:error, {:handler_error, {:handler_throw, :throw_bomb}}} = Poller.poll_once(poller)

      # Offset must be 402, NOT 403 or 404
      assert Poller.get_offset(poller) == 402

      assert_receive {:handled, 401}
      refute_receive {:handled, 403}

      Poller.stop(poller)
    end

    test "fn handler exiting halts batch and preserves unadvanced offset" do
      test_pid = self()

      exiting_handler = fn signal ->
        if signal.payload["update_id"] == 502 do
          exit(:killed)
        else
          send(test_pid, {:handled, signal.payload["update_id"]})
        end
      end

      updates = [
        %{"update_id" => 501, "message" => %{"text" => "msg 501"}},
        %{"update_id" => 502, "message" => %{"text" => "msg 502"}},
        %{"update_id" => 503, "message" => %{"text" => "msg 503"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: exiting_handler,
          autostart: false,
          offset: 500
        })

      assert {:error, {:handler_error, {:handler_exit, :killed}}} = Poller.poll_once(poller)

      assert Poller.get_offset(poller) == 502
      assert_receive {:handled, 501}
      refute_receive {:handled, 503}

      Poller.stop(poller)
    end

    test "fn handler returning {:error, reason} halts batch and preserves unadvanced offset" do
      test_pid = self()

      error_handler = fn signal ->
        if signal.payload["update_id"] == 602 do
          {:error, :db_write_failure}
        else
          send(test_pid, {:handled, signal.payload["update_id"]})
          :ok
        end
      end

      updates = [
        %{"update_id" => 601, "message" => %{"text" => "msg 601"}},
        %{"update_id" => 602, "message" => %{"text" => "msg 602"}},
        %{"update_id" => 603, "message" => %{"text" => "msg 603"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: error_handler,
          autostart: false,
          offset: 600
        })

      assert {:error, {:handler_error, :db_write_failure}} = Poller.poll_once(poller)

      assert Poller.get_offset(poller) == 602
      assert_receive {:handled, 601}
      refute_receive {:handled, 603}

      Poller.stop(poller)
    end

    test "fn handler returning :error halts batch and preserves unadvanced offset" do
      test_pid = self()

      error_handler = fn signal ->
        if signal.payload["update_id"] == 702 do
          :error
        else
          send(test_pid, {:handled, signal.payload["update_id"]})
          :ok
        end
      end

      updates = [
        %{"update_id" => 701, "message" => %{"text" => "msg 701"}},
        %{"update_id" => 702, "message" => %{"text" => "msg 702"}},
        %{"update_id" => 703, "message" => %{"text" => "msg 703"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: error_handler,
          autostart: false,
          offset: 700
        })

      assert {:error, {:handler_error, :handler_error}} = Poller.poll_once(poller)

      assert Poller.get_offset(poller) == 702
      assert_receive {:handled, 701}
      refute_receive {:handled, 703}

      Poller.stop(poller)
    end

    test "single-update batch with crashing fn handler preserves initial offset" do
      crashing_handler = fn _sig -> raise "Single crash" end

      updates = [%{"update_id" => 800, "message" => %{"text" => "msg 800"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: crashing_handler,
          autostart: false,
          offset: 750
        })

      assert {:error, {:handler_error, _}} = Poller.poll_once(poller)
      # Offset should remain initial 750
      assert Poller.get_offset(poller) == 750

      Poller.stop(poller)
    end
  end

  # ============================================================================
  # 4. POLLER R1: MODULE HANDLER FAILURE MODES IN POLL_ONCE
  # ============================================================================

  describe "Poller R1: Module handler failure modes in poll_once do not advance offset" do
    test "module handle_signal/1 raising exception preserves offset and reports error" do
      updates = [%{"update_id" => 901, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: CrashRaiseSignalHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, {:handler_exception, %RuntimeError{}}}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "module handle_signal/1 throwing term preserves offset and reports error" do
      updates = [%{"update_id" => 902, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: CrashThrowSignalHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, {:handler_throw, :module_signal_throw_bomb}}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "module handle_signal/1 exiting preserves offset and reports error" do
      updates = [%{"update_id" => 903, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: CrashExitSignalHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, {:handler_exit, :module_signal_kill}}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "module handle_signal/1 returning {:error, reason} preserves offset and reports error" do
      updates = [%{"update_id" => 904, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: ErrorTupleSignalHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, :database_connection_lost}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "module handle_signal/1 returning :error preserves offset and reports error" do
      updates = [%{"update_id" => 905, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: ErrorAtomSignalHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, :handler_error}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "module handle_update/1 raising exception preserves offset and reports error" do
      updates = [%{"update_id" => 906, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: CrashRaiseUpdateHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, {:handler_exception, %RuntimeError{}}}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "module handle_update/1 throwing term preserves offset and reports error" do
      updates = [%{"update_id" => 907, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: CrashThrowUpdateHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, {:handler_throw, :module_update_throw_bomb}}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "module handle_update/1 exiting preserves offset and reports error" do
      updates = [%{"update_id" => 908, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: CrashExitUpdateHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, {:handler_exit, :module_update_kill}}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "module handle_update/1 returning {:error, reason} preserves offset and reports error" do
      updates = [%{"update_id" => 909, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: ErrorTupleUpdateHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, :upstream_timeout}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "module handle_update/1 returning :error preserves offset and reports error" do
      updates = [%{"update_id" => 910, "message" => %{"text" => "msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: ErrorAtomUpdateHandler,
          autostart: false,
          offset: 900
        })

      assert {:error, {:handler_error, :handler_error}} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 900

      Poller.stop(poller)
    end

    test "successful module handle_signal/1 advances offset and dispatches" do
      if Process.whereis(:test_receiver), do: Process.unregister(:test_receiver)
      Process.register(self(), :test_receiver)

      updates = [%{"update_id" => 920, "message" => %{"text" => "ok signal"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: SuccessSignalHandler,
          autostart: false,
          offset: 900
        })

      assert {:ok, [_signal]} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 921
      assert_receive {:module_signal_ok, sig}
      assert sig.payload["update_id"] == 920

      Poller.stop(poller)
      Process.unregister(:test_receiver)
    end

    test "successful module handle_update/1 advances offset and dispatches" do
      if Process.whereis(:test_receiver), do: Process.unregister(:test_receiver)
      Process.register(self(), :test_receiver)

      updates = [%{"update_id" => 930, "message" => %{"text" => "ok update"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: SuccessUpdateHandler,
          autostart: false,
          offset: 900
        })

      assert {:ok, [_signal]} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 931
      assert_receive {:module_update_ok, sig}
      assert sig.payload["update_id"] == 930

      Poller.stop(poller)
      Process.unregister(:test_receiver)
    end
  end

  # ============================================================================
  # 5. POLLER R1: ASYNCHRONOUS POLLING LOOP (handle_info(:poll))
  # ============================================================================

  describe "Poller R1: Asynchronous polling loop (handle_info(:poll)) handler failures" do
    test "handle_info(:poll) survives handler crash and preserves offset without terminating GenServer" do
      crashing_handler = fn _sig -> raise "Async loop crash" end

      updates = [%{"update_id" => 1001, "message" => %{"text" => "async msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: crashing_handler,
          autostart: false,
          offset: 1000
        })

      # Trigger handle_info(:poll)
      send(poller, :poll)
      # Give GenServer time to process message
      Process.sleep(50)

      # GenServer must be alive and offset must remain 1000
      assert Process.alive?(poller)
      assert Poller.get_offset(poller) == 1000

      Poller.stop(poller)
    end

    test "handle_info(:poll) survives handler throw and preserves offset without terminating GenServer" do
      throwing_handler = fn _sig -> throw(:async_throw) end

      updates = [%{"update_id" => 1002, "message" => %{"text" => "async msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: throwing_handler,
          autostart: false,
          offset: 1000
        })

      send(poller, :poll)
      Process.sleep(50)

      assert Process.alive?(poller)
      assert Poller.get_offset(poller) == 1000

      Poller.stop(poller)
    end

    test "handle_info(:poll) survives handler error tuple and preserves offset" do
      error_handler = fn _sig -> {:error, :async_error} end

      updates = [%{"update_id" => 1003, "message" => %{"text" => "async msg"}}]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: error_handler,
          autostart: false,
          offset: 1000
        })

      send(poller, :poll)
      Process.sleep(50)

      assert Process.alive?(poller)
      assert Poller.get_offset(poller) == 1000

      Poller.stop(poller)
    end
  end

  # ============================================================================
  # 6. POLLER SCHEMA POISON-PILL IMMUNITY (MALFORMED UPDATES ADVANCE OFFSET)
  # ============================================================================

  describe "Poller: Malformed / unparseable schema updates advance offset to prevent deadlocks" do
    test "malformed schema updates are dropped while advancing offset" do
      test_pid = self()

      raw_updates = [
        # Missing update_id (ignored, cannot determine next offset)
        %{"message" => %{"text" => "no_id"}},
        # Corrupted update schema with integer update_id 1100
        %{"update_id" => 1100, "message" => "invalid_message_string_not_map"},
        # Corrupted update schema with callback_query as boolean
        %{"update_id" => 1105, "callback_query" => true},
        # Valid update 1110
        %{"update_id" => 1110, "message" => %{"text" => "valid message"}},
        # Corrupted update schema with poll as number
        %{"update_id" => 1115, "poll" => 12345},
        # Valid update 1120
        %{"update_id" => 1120, "message" => %{"text" => "valid message 2"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => raw_updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: test_pid,
          autostart: false,
          offset: 1050
        })

      assert {:ok, signals} = Poller.poll_once(poller)
      # Only the 2 valid updates are converted to signals
      assert length(signals) == 2
      assert Enum.map(signals, & &1.payload["update_id"]) == [1110, 1120]

      # Offset must advance to max(1050, 1100+1, 1105+1, 1110+1, 1115+1, 1120+1) == 1121!
      assert Poller.get_offset(poller) == 1121

      assert_receive {:telegram_update, s1}
      assert s1.payload["update_id"] == 1110
      assert_receive {:telegram_update, s2}
      assert s2.payload["update_id"] == 1120
      refute_receive {:telegram_update, _}

      Poller.stop(poller)
    end

    test "single malformed update with valid update_id advances offset and returns empty signals" do
      malformed_update = %{"update_id" => 1200, "message" => 99999}

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => [malformed_update]}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: self(),
          autostart: false,
          offset: 1100
        })

      assert {:ok, []} = Poller.poll_once(poller)
      # Offset must advance to 1201 to avoid endless retry loop on the unparseable update
      assert Poller.get_offset(poller) == 1201
      refute_receive {:telegram_update, _}

      Poller.stop(poller)
    end

    test "batch containing only malformed updates advances offset to highest update_id + 1" do
      malformed_batch = [
        %{"update_id" => 1301, "message" => "bad_1"},
        %{"update_id" => 1305, "message" => "bad_2"},
        %{"update_id" => 1303, "message" => "bad_3"}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => malformed_batch}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: self(),
          autostart: false,
          offset: 1300
        })

      assert {:ok, []} = Poller.poll_once(poller)
      # Offset should be max(1300, 1301+1, 1305+1, 1303+1) == 1306
      assert Poller.get_offset(poller) == 1306
      refute_receive {:telegram_update, _}

      Poller.stop(poller)
    end
  end

  # ============================================================================
  # 7. POLLER BATCH CORRUPTION, MONOTONICITY, AND PROPERTY TESTING
  # ============================================================================

  describe "Poller: process_updates/3 adversarial inputs" do
    test "drops all non-map items in updates list and preserves valid signals" do
      test_pid = self()
      non_map_items = [
        :atom_item,
        nil,
        true,
        false,
        "string_item",
        "",
        <<0, 255, 128>>,
        12345,
        -999,
        0,
        3.14159,
        [],
        [1, 2, 3],
        [%{"update_id" => 500}],
        {:tuple, :not, :allowed}
      ]

      valid_update_1 = %{"update_id" => 10, "message" => %{"text" => "First"}}
      valid_update_2 = %{"update_id" => 20, "message" => %{"text" => "Second"}}

      corrupted_updates = [valid_update_1 | non_map_items] ++ [valid_update_2]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => Enum.filter(corrupted_updates, &is_map/1)
        }))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: test_pid,
          autostart: false,
          offset: 0
        })

      assert {:ok, signals} = Poller.poll_once(poller)
      assert length(signals) == 2
      assert Enum.map(signals, & &1.payload["update_id"]) == [10, 20]
      assert Poller.get_offset(poller) == 21

      assert_receive {:telegram_update, sig1}
      assert sig1.payload["update_id"] == 10
      assert_receive {:telegram_update, sig2}
      assert sig2.payload["update_id"] == 20
      refute_receive {:telegram_update, _}

      Poller.stop(poller)
    end

    test "handles malformed update_id variations and advances offset correctly for non-negative IDs" do
      test_pid = self()

      raw_updates = [
        # missing update_id
        %{"message" => %{"text" => "no_id"}},
        # string update_id with invalid format
        %{"update_id" => "invalid_string_id", "message" => %{"text" => "bad_str"}},
        # negative string update_id
        %{"update_id" => "-50", "message" => %{"text" => "neg_str"}},
        # float update_id
        %{"update_id" => 99.9, "message" => %{"text" => "float_id"}},
        # nil update_id
        %{"update_id" => nil, "message" => %{"text" => "nil_id"}},
        # boolean update_id
        %{"update_id" => true, "message" => %{"text" => "bool_id"}},
        # list update_id
        %{"update_id" => [100], "message" => %{"text" => "list_id"}},
        # valid update 1
        %{"update_id" => 100, "message" => %{"text" => "Valid 100"}},
        # corrupt schema with valid update_id 105
        %{"update_id" => 105, "message" => "invalid_message_string"},
        # valid update 2
        %{"update_id" => 110, "message" => %{"text" => "Valid 110"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => raw_updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: test_pid,
          autostart: false,
          offset: 50
        })

      assert {:ok, signals} = Poller.poll_once(poller)
      assert length(signals) == 2
      assert Enum.map(signals, & &1.payload["update_id"]) == [100, 110]

      # Offset must be max(50, 100+1, 105+1, 110+1) == 111
      assert Poller.get_offset(poller) == 111

      assert_receive {:telegram_update, s1}
      assert s1.payload["update_id"] == 100
      assert_receive {:telegram_update, s2}
      assert s2.payload["update_id"] == 110

      refute_receive {:telegram_update, {:error, _}}
      refute_receive {:telegram_update, _}

      Poller.stop(poller)
    end

    test "negative update_id does not advance offset" do
      test_pid = self()

      raw_updates = [
        %{"update_id" => -10, "message" => %{"text" => "neg_int"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => raw_updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: test_pid,
          autostart: false,
          offset: 50
        })

      assert {:ok, [signal]} = Poller.poll_once(poller)
      assert signal.payload["update_id"] == -10
      # Offset should remain 50 because update_id was negative
      assert Poller.get_offset(poller) == 50

      Poller.stop(poller)
    end

    test "handles out-of-order batches and maintains monotonically increasing offset" do
      test_pid = self()

      out_of_order_updates = [
        %{"update_id" => 750, "message" => %{"text" => "750"}},
        %{"update_id" => 700, "message" => %{"text" => "700"}},
        %{"update_id" => 800, "message" => %{"text" => "800"}},
        %{"update_id" => 720, "message" => %{"text" => "720"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => out_of_order_updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: test_pid,
          autostart: false,
          offset: 600
        })

      assert {:ok, signals} = Poller.poll_once(poller)
      assert length(signals) == 4
      assert Poller.get_offset(poller) == 801

      Poller.stop(poller)
    end

    test "preserves current offset when batch updates are older than current offset" do
      test_pid = self()

      older_updates = [
        %{"update_id" => 100, "message" => %{"text" => "100"}},
        %{"update_id" => 200, "message" => %{"text" => "200"}}
      ]

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => older_updates}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: test_pid,
          autostart: false,
          offset: 1000
        })

      assert {:ok, signals} = Poller.poll_once(poller)
      assert length(signals) == 2
      # Offset should remain 1000 because 1000 > 200 + 1
      assert Poller.get_offset(poller) == 1000

      Poller.stop(poller)
    end

    test "handles completely empty batch without changing offset" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => []}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: "dummy_tok",
          plug: plug,
          handler: self(),
          autostart: false,
          offset: 42
        })

      assert {:ok, []} = Poller.poll_once(poller)
      assert Poller.get_offset(poller) == 42
      refute_receive {:telegram_update, _}

      Poller.stop(poller)
    end

    test "generative randomized batch property test (50 iterations)" do
      for batch_idx <- 1..50 do
        initial_offset = :rand.uniform(10_000)

        item_count = :rand.uniform(20)
        items =
          Enum.map(1..item_count, fn i ->
            case :rand.uniform(6) do
              1 ->
                # Valid update
                %{"update_id" => initial_offset + i * 2, "message" => %{"text" => "msg_#{i}"}}

              2 ->
                # Non-map item
                case :rand.uniform(4) do
                  1 -> "corrupt_string_#{i}"
                  2 -> :rand.uniform(1000)
                  3 -> nil
                  4 -> ["nested", "list"]
                end

              3 ->
                # Missing update_id
                %{"message" => %{"text" => "no_update_id_#{i}"}}

              4 ->
                # Corrupt schema with valid update_id
                %{"update_id" => initial_offset + i * 2 + 1, "message" => 12345}

              5 ->
                # Invalid update_id format
                %{"update_id" => "not_int", "message" => %{"text" => "bad_id"}}

              6 ->
                # Negative update_id
                %{"update_id" => -:rand.uniform(100), "message" => %{"text" => "negative"}}
            end
          end)

        valid_maps = Enum.filter(items, &is_map/1)

        plug = fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => valid_maps}))
        end

        {:ok, poller} =
          Poller.start_link(%{
            token: "dummy_tok_#{batch_idx}",
            plug: plug,
            handler: self(),
            autostart: false,
            offset: initial_offset
          })

        assert {:ok, signals} = Poller.poll_once(poller)

        # Invariant 1: All returned items are valid Lux.Signal structs
        for sig <- signals do
          assert %Lux.Signal{} = sig
          assert is_integer(sig.payload["update_id"])
        end

        # Invariant 2: Offset is monotonically non-decreasing
        new_offset = Poller.get_offset(poller)
        assert new_offset >= initial_offset, "Offset decreased from #{initial_offset} to #{new_offset}"

        # Clean up any received messages and stop poller
        flush_messages()
        Poller.stop(poller)
      end
    end
  end

  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end
end
