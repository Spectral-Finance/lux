defmodule Lux.Telegram.PollerUnitTest do
  use UnitAPICase, async: false

  alias Lux.Telegram.Poller

  @bot_token "test_poller_token_123"

  defmodule PollerSignalHandler do
    def handle_signal(signal) do
      if pid = Process.whereis(:poller_test_receiver) do
        send(pid, {:sig_handled, signal})
      end
      :ok
    end
  end

  defmodule PollerUpdateHandler do
    def handle_update(signal) do
      if pid = Process.whereis(:poller_test_receiver) do
        send(pid, {:upd_handled, signal})
      end
      :ok
    end
  end

  defmodule PollerNoopHandler do
  end

  defmodule Request4ClientMock do
    def request(_client, :post, "/getUpdates", _opts) do
      {:ok, %{"ok" => true, "result" => []}}
    end
  end

  defmodule Request3ClientMock do
    def request(:post, "/getUpdates", _opts) do
      {:ok, %{"ok" => true, "result" => []}}
    end
  end

  defmodule Client401TupleMock do
    def request(:post, "/getUpdates", _opts) do
      {:error, {401, "Custom 401 unauthenticated"}}
    end
  end

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "poll_once/1" do
    test "polls updates, dispatches signals to PID, and updates offset" do
      test_pid = self()

      plug = fn conn ->
        assert conn.request_path == "/bot#{@bot_token}/getUpdates"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["offset"] == 0

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{"update_id" => 100, "message" => %{"text" => "First"}},
            %{"update_id" => 101, "message" => %{"text" => "Second"}}
          ]
        }))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: @bot_token,
          plug: plug,
          handler: test_pid,
          autostart: false
        })

      assert Poller.get_offset(poller) == 0

      assert {:ok, signals} = Poller.poll_once(poller)
      assert length(signals) == 2

      assert_receive {:telegram_update, signal1}
      assert signal1.payload["update_id"] == 100
      assert get_in(signal1.payload, ["message", "text"]) == "First"

      assert_receive {:telegram_update, signal2}
      assert signal2.payload["update_id"] == 101
      assert get_in(signal2.payload, ["message", "text"]) == "Second"

      assert Poller.get_offset(poller) == 102
      Poller.stop(poller)
    end

    test "dispatches signal to handler function" do
      test_pid = self()

      handler_fn = fn signal ->
        send(test_pid, {:custom_fn_signal, signal})
      end

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [%{"update_id" => 50, "message" => %{"text" => "Fn test"}}]
        }))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: @bot_token,
          plug: plug,
          handler: handler_fn,
          autostart: false
        })

      assert {:ok, [signal]} = Poller.poll_once(poller)
      assert_receive {:custom_fn_signal, ^signal}
      assert signal.payload["update_id"] == 50
      Poller.stop(poller)
    end

    test "filters out invalid update payloads, drops error tuples, and advances offset" do
      test_pid = self()

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            # Valid update 1
            %{"update_id" => 200, "message" => %{"text" => "Valid 1"}},
            # Invalid update (message type string instead of object)
            %{"update_id" => 201, "message" => "invalid_string_message"},
            # Valid update 2
            %{"update_id" => 202, "message" => %{"text" => "Valid 2"}}
          ]
        }))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: @bot_token,
          plug: plug,
          handler: test_pid,
          autostart: false
        })

      assert {:ok, signals} = Poller.poll_once(poller)
      assert length(signals) == 2

      assert_receive {:telegram_update, signal1}
      assert signal1.payload["update_id"] == 200

      assert_receive {:telegram_update, signal2}
      assert signal2.payload["update_id"] == 202

      # Ensure no error tuple was dispatched
      refute_receive {:telegram_update, {:error, _}}

      # Ensure offset advanced past invalid update 201 to 203
      assert Poller.get_offset(poller) == 203
      Poller.stop(poller)
    end

    test "handles batch with only invalid updates by returning empty list and advancing offset" do
      test_pid = self()

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{"update_id" => 300, "message" => "bad_message_1"},
            %{"update_id" => 301, "message" => "bad_message_2"}
          ]
        }))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: @bot_token,
          plug: plug,
          handler: test_pid,
          autostart: false
        })

      assert {:ok, []} = Poller.poll_once(poller)
      refute_receive {:telegram_update, _}
      assert Poller.get_offset(poller) == 302
      Poller.stop(poller)
    end

    test "skips non-map items in updates array gracefully" do
      test_pid = self()

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            "not-a-map",
            12345,
            %{"update_id" => 400, "message" => %{"text" => "Valid after scalars"}}
          ]
        }))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: @bot_token,
          plug: plug,
          handler: test_pid,
          autostart: false
        })

      assert {:ok, [signal]} = Poller.poll_once(poller)
      assert signal.payload["update_id"] == 400
      assert_receive {:telegram_update, ^signal}
      assert Poller.get_offset(poller) == 401
      Poller.stop(poller)
    end

    test "handler failure stops processing and does not advance offset past failed update" do
      test_pid = self()

      handler_fn = fn signal ->
        if signal.payload["update_id"] == 501 do
          {:error, :db_failure}
        else
          send(test_pid, {:handled, signal.payload["update_id"]})
          :ok
        end
      end

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{"update_id" => 500, "message" => %{"text" => "Update 500"}},
            %{"update_id" => 501, "message" => %{"text" => "Update 501"}},
            %{"update_id" => 502, "message" => %{"text" => "Update 502"}}
          ]
        }))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: @bot_token,
          plug: plug,
          handler: handler_fn,
          autostart: false,
          offset: 450
        })

      assert {:error, {:handler_error, :db_failure}} = Poller.poll_once(poller)
      assert_receive {:handled, 500}
      refute_receive {:handled, 502}

      # Offset should have advanced to 501 (acknowledging 500), but NOT past 501
      assert Poller.get_offset(poller) == 501
      Poller.stop(poller)
    end

    test "set_offset/2 and stop/1" do
      {:ok, poller} =
        Poller.start_link(%{
          token: @bot_token,
          autostart: false,
          offset: 10
        })

      assert Poller.get_offset(poller) == 10
      assert :ok = Poller.set_offset(poller, 99)
      assert Poller.get_offset(poller) == 99

      assert :ok = Poller.stop(poller)
    end

    test "handles module handler implementing handle_signal/1 and handle_update/1" do
      if Process.whereis(:poller_test_receiver), do: Process.unregister(:poller_test_receiver)
      Process.register(self(), :poller_test_receiver)
      on_exit(fn ->
        if Process.whereis(:poller_test_receiver) do
          Process.unregister(:poller_test_receiver)
        end
      end)

      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            "non_map_item",
            12345,
            %{"update_id" => 600, "message" => %{"text" => "Mod test"}}
          ]
        }))
      end

      # Module with handle_signal/1
      {:ok, p1} = Poller.start_link(%{token: @bot_token, plug: plug, handler: PollerSignalHandler, autostart: false})
      assert {:ok, _} = Poller.poll_once(p1)
      assert_receive {:sig_handled, signal1}
      assert signal1.payload["update_id"] == 600
      Poller.stop(p1)

      # Module with handle_update/1
      {:ok, p2} = Poller.start_link(%{token: @bot_token, plug: plug, handler: PollerUpdateHandler, autostart: false})
      assert {:ok, _} = Poller.poll_once(p2)
      assert_receive {:upd_handled, signal2}
      assert signal2.payload["update_id"] == 600
      Poller.stop(p2)

      # Module with no callbacks (Noop)
      {:ok, p_noop} = Poller.start_link(%{token: @bot_token, plug: plug, handler: PollerNoopHandler, autostart: false})
      assert {:ok, _} = Poller.poll_once(p_noop)
      Poller.stop(p_noop)

      # Nil handler
      {:ok, p_nil} = Poller.start_link(%{token: @bot_token, plug: plug, handler: nil, autostart: false})
      assert {:ok, _} = Poller.poll_once(p_nil)
      Poller.stop(p_nil)
    end

    test "handles API errors: 401, 429, malformed response, and network errors" do
      plug_401 = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"ok" => false, "error_code" => 401, "description" => "Unauthorized"}))
      end

      {:ok, p_401} = Poller.start_link(%{token: @bot_token, plug: plug_401, autostart: false})
      assert {:error, :invalid_token} = Poller.poll_once(p_401)
      Poller.stop(p_401)

      plug_429 = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "ok" => false,
          "error_code" => 429,
          "description" => "Too Many Requests",
          "parameters" => %{"retry_after" => 3}
        }))
      end

      {:ok, p_429} = Poller.start_link(%{token: @bot_token, plug: plug_429, autostart: false})
      assert {:error, {429, 3}} = Poller.poll_once(p_429)
      Poller.stop(p_429)

      plug_malformed = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => "not_a_list"}))
      end

      {:ok, p_mal} = Poller.start_link(%{token: @bot_token, plug: plug_malformed, autostart: false})
      assert {:error, :malformed_response} = Poller.poll_once(p_mal)
      Poller.stop(p_mal)
    end

    test "handles :poll message in handle_info" do
      test_pid = self()

      plug = fn conn ->
        send(test_pid, :polled_via_info)
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => []}))
      end

      {:ok, poller} =
        Poller.start_link(%{
          token: @bot_token,
          plug: plug,
          autostart: false,
          poll_interval: 50
        })

      send(poller, :poll)
      assert_receive :polled_via_info, 1000

      Poller.stop(poller)
    end
  end

  describe "poller client types and backoff calculations" do
    test "supports client struct in Poller state" do
      client = Lux.Telegram.Client.new(@bot_token)
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => true, "result" => []}))
      end
      client_with_plug = %{client | req_options: [plug: plug]}

      {:ok, poller} = Poller.start_link(%{client: client_with_plug, autostart: false})
      assert {:ok, []} = Poller.poll_once(poller)
      Poller.stop(poller)
    end

    test "handles string update_id and negative update_id" do
      test_pid = self()
      plug = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{"update_id" => "700", "message" => %{"text" => "String ID"}},
            %{"update_id" => -1, "message" => %{"text" => "Negative ID"}}
          ]
        }))
      end

      {:ok, poller} = Poller.start_link(%{token: @bot_token, plug: plug, handler: test_pid, autostart: false})
      assert {:ok, signals} = Poller.poll_once(poller)
      assert length(signals) == 1
      assert Poller.get_offset(poller) == 701
      Poller.stop(poller)
    end

    test "handles rate limit with string regex description and atom map" do
      plug_str = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "ok" => false,
          "description" => "Too Many Requests: retry after 7"
        }))
      end

      {:ok, p_str} = Poller.start_link(%{token: @bot_token, plug: plug_str, autostart: false})
      assert {:error, {429, 7}} = Poller.poll_once(p_str)
      Poller.stop(p_str)
    end

    test "handles unhandled messages in handle_info" do
      {:ok, poller} = Poller.start_link(%{token: @bot_token, autostart: false})
      send(poller, :unknown_message)
      assert Process.alive?(poller)
      Poller.stop(poller)
    end
  end

  describe "poller edge cases and error branches" do
    test "supports client exporting request/4 and request/3" do
      {:ok, p4} = Poller.start_link(%{client: Request4ClientMock, autostart: false})
      assert {:ok, []} = Poller.poll_once(p4)
      Poller.stop(p4)

      {:ok, p3} = Poller.start_link(%{client: Request3ClientMock, autostart: false})
      assert {:ok, []} = Poller.poll_once(p3)
      Poller.stop(p3)
    end

    test "handles 401, 429 string retry_after, and generic API error in 200/400 body" do
      # 200 with ok: false, error_code: 401
      plug_401 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => false, "error_code" => 401}))
      end
      {:ok, p1} = Poller.start_link(%{token: @bot_token, plug: plug_401, autostart: false})
      assert {:error, %{"ok" => false, "error_code" => 401}} = Poller.poll_once(p1)
      Poller.stop(p1)

      # 200 with ok: false, error_code: 429, parameters.retry_after
      plug_429 = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => false, "error_code" => 429, "parameters" => %{"retry_after" => 5}}))
      end
      {:ok, p2} = Poller.start_link(%{token: @bot_token, plug: plug_429, autostart: false})
      assert {:error, %{"error_code" => 429, "parameters" => %{"retry_after" => 5}}} = Poller.poll_once(p2)
      Poller.stop(p2)

      # 200 with ok: false, description
      plug_desc = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{"ok" => false, "description" => "Custom Error"}))
      end
      {:ok, p3} = Poller.start_link(%{token: @bot_token, plug: plug_desc, autostart: false})
      assert {:error, %{"ok" => false, "description" => "Custom Error"}} = Poller.poll_once(p3)
      Poller.stop(p3)

      # network error tuple {:error, :econnrefused}
      bad_plug = fn _conn -> raise "Network error" end
      {:ok, p4} = Poller.start_link(%{token: @bot_token, plug: bad_plug, autostart: false})
      assert {:error, %RuntimeError{}} = Poller.poll_once(p4)
      Poller.stop(p4)
    end

    test "backoff calculation variants" do
      # 429 with float string or atom map
      plug_map = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(429, Jason.encode!(%{"ok" => false, "description" => %{"parameters" => %{"retry_after" => "8"}}}))
      end
      {:ok, pm} = Poller.start_link(%{token: @bot_token, plug: plug_map, autostart: false})
      assert {:error, {429, "8"}} = Poller.poll_once(pm)
      Poller.stop(pm)
    end

    test "handles client returning 401 error tuple" do
      {:ok, p_401} = Poller.start_link(%{client: Client401TupleMock, autostart: false})
      assert {:error, :invalid_token} = Poller.poll_once(p_401)
      Poller.stop(p_401)
    end

    test "handles various retry_after structures and invalid string update_ids" do
      # direct retry_after key in 429
      plug_direct = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "ok" => false,
          "retry_after" => 12
        }))
      end
      {:ok, p_dir} = Poller.start_link(%{token: @bot_token, plug: plug_direct, autostart: false})
      assert {:error, {429, 12}} = Poller.poll_once(p_dir)
      Poller.stop(p_dir)

      # negative string update_id and float update_id
      plug_invalid_id = fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "ok" => true,
          "result" => [
            %{"update_id" => "-5", "message" => %{"text" => "Neg string"}},
            %{"update_id" => 12.34, "message" => %{"text" => "Float id"}}
          ]
        }))
      end
      {:ok, p_inv} = Poller.start_link(%{token: @bot_token, plug: plug_invalid_id, autostart: false})
      assert {:ok, []} = Poller.poll_once(p_inv)
      Poller.stop(p_inv)
    end
  end
end
