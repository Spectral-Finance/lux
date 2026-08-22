defmodule Lux.Binance.AdversarialStressTest do
  use ExUnit.Case, async: false

  alias Lux.Binance.WebSocket.Client, as: WSClient
  alias Lux.Binance.WebSocket.UserDataStream
  alias Lux.Prisms.Binance.SpotAccountPrism
  alias Lux.Prisms.Binance.SpotCancelOrderPrism
  alias Lux.Prisms.Binance.SpotOpenOrdersPrism
  alias Lux.Prisms.Binance.SpotOrderPrism
  alias Lux.Prisms.Binance.FuturesAccountPrism
  alias Lux.Prisms.Binance.FuturesCancelOrderPrism
  alias Lux.Prisms.Binance.FuturesOrderPrism

  setup context do
    Req.Test.verify_on_exit!(context)
    :ok
  end

  # Helper for JSON error response
  defp json_error(conn, body, status_code) do
    conn
    |> Plug.Conn.put_status(status_code)
    |> Req.Test.json(body)
  end

  def start_mock_server do
    case :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true]) do
      {:ok, listen_socket} ->
        {:ok, port} = :inet.port(listen_socket)

        Task.start(fn ->
          mock_server_loop(listen_socket)
        end)

        {:ok, port}

      error ->
        error
    end
  end

  defp mock_server_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        Task.start(fn -> handle_mock_client(socket) end)
        mock_server_loop(listen_socket)

      {:error, _} ->
        :ok
    end
  end

  defp handle_mock_client(socket) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, req} ->
        case Regex.run(~r/Sec-WebSocket-Key:\s*([^\r\n]+)/i, req) do
          [_, key] ->
            accept_key = :crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11") |> Base.encode64()
            resp = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{accept_key}\r\n\r\n"
            :gen_tcp.send(socket, resp)
            keep_socket_open(socket)

          _ ->
            :gen_tcp.close(socket)
        end

      {:error, _} ->
        :gen_tcp.close(socket)
    end
  end

  defp keep_socket_open(socket) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, _} -> keep_socket_open(socket)
      {:error, _} -> :gen_tcp.close(socket)
    end
  end

  # ===================================================================
  # SECTION 1: WEBSOCKET STREAM AUTO-RECONNECTION & EVENT HANDLING
  # ===================================================================

  describe "WebSocket.Client Event Handling & Malformed Input Resilience" do
    setup do
      {:ok, port} = start_mock_server()
      %{mock_url: "ws://127.0.0.1:#{port}"}
    end

    test "processes valid market event frames and emits signal, ws_event, and event tuples", %{mock_url: mock_url} do
      {:ok, pid} = WSClient.start_link(subscriber: self(), streams: ["btcusdt@trade"], url: mock_url)

      assert_receive {:ws_subscribed, %{"method" => "SUBSCRIBE", "params" => ["btcusdt@trade"]}}, 1000

      trade_frame = Jason.encode!(%{
        "e" => "trade",
        "E" => 1672515782136,
        "s" => "BTCUSDT",
        "t" => 12345,
        "p" => "95000.00",
        "q" => "0.05",
        "b" => 88888,
        "a" => 99999,
        "T" => 1672515782130,
        "m" => true
      })

      WSClient.handle_incoming_frame(pid, trade_frame)

      assert_receive {:ws_event, %{"e" => "trade", "s" => "BTCUSDT", "p" => "95000.00"}}, 1000
      assert_receive {:signal, %Lux.Signal{sender: "Elixir.Lux.Binance.WebSocket.Client", payload: %{"p" => "95000.00"}}}, 1000
      assert_receive {:event, "trade", %{"s" => "BTCUSDT"}}, 1000
      assert Process.alive?(pid)
    end

    test "handles corrupted JSON without crashing GenServer process", %{mock_url: mock_url} do
      {:ok, pid} = WSClient.start_link(subscriber: self(), url: mock_url)
      WSClient.handle_incoming_frame(pid, "{invalid_json: true, missing_quotes: hello")

      assert Process.alive?(pid)
      refute_receive {:ws_event, _}, 200
    end

    test "handles non-map JSON values (strings, arrays, booleans, nulls) safely", %{mock_url: mock_url} do
      {:ok, pid} = WSClient.start_link(subscriber: self(), url: mock_url)

      WSClient.handle_incoming_frame(pid, Jason.encode!("just a string"))
      assert_receive {:ws_frame, "just a string"}, 1000

      WSClient.handle_incoming_frame(pid, Jason.encode!([1, 2, 3]))
      assert_receive {:ws_frame, [1, 2, 3]}, 1000

      WSClient.handle_incoming_frame(pid, Jason.encode!(true))
      assert_receive {:ws_frame, true}, 1000

      WSClient.handle_incoming_frame(pid, Jason.encode!(nil))
      assert_receive {:ws_frame, nil}, 1000

      assert Process.alive?(pid)
    end

    test "handles binary/non-UTF8 malformed frame payload without crashing", %{mock_url: mock_url} do
      {:ok, pid} = WSClient.start_link(subscriber: self(), url: mock_url)
      send(pid, {:incoming_frame, <<255, 255, 255, 0, 128>>})

      Process.sleep(50)
      assert Process.alive?(pid)
    end

    test "handles Binance WebSocket server ping frame and responds with ws_pong", %{mock_url: mock_url} do
      {:ok, pid} = WSClient.start_link(subscriber: self(), url: mock_url)

      ping_frame = Jason.encode!(%{"ping" => 1672515782})
      WSClient.handle_incoming_frame(pid, ping_frame)

      assert_receive {:ws_pong, 1672515782}, 1000

      send(pid, :ping)
      assert_receive {:ws_pong, "pong"}, 1000

      send(pid, {:ping, "custom_ping_data"})
      assert_receive {:ws_pong, "custom_ping_data"}, 1000

      assert Process.alive?(pid)
    end

    test "handles subscription and unsubscription lifecycle with stream list updates", %{mock_url: mock_url} do
      {:ok, pid} = WSClient.start_link(subscriber: self(), url: mock_url)

      assert :ok == WSClient.subscribe(pid, ["btcusdt@depth5", "ethusdt@kline_1m"])
      assert_receive {:ws_subscribed, %{"method" => "SUBSCRIBE", "params" => ["btcusdt@depth5", "ethusdt@kline_1m"]}}, 1000

      assert :ok == WSClient.unsubscribe(pid, "btcusdt@depth5")
      assert_receive {:ws_unsubscribed, %{"method" => "UNSUBSCRIBE", "params" => ["btcusdt@depth5"]}}, 1000

      assert Process.alive?(pid)
    end

    test "tests stream re-subscription on re-connect trigger message", %{mock_url: mock_url} do
      {:ok, pid} = WSClient.start_link(subscriber: self(), streams: ["btcusdt@trade", "solusdt@ticker"], url: mock_url)
      assert_receive {:ws_subscribed, %{"method" => "SUBSCRIBE"}}, 1000

      send(pid, :send_subscription_frame)
      assert_receive {:ws_subscribed, %{"method" => "SUBSCRIBE", "params" => params}}, 1000
      assert Enum.sort(params) == ["btcusdt@trade", "solusdt@ticker"]
    end

    test "handles unknown GenServer info messages without crash", %{mock_url: mock_url} do
      {:ok, pid} = WSClient.start_link(subscriber: self(), url: mock_url)
      send(pid, :unknown_event_type)
      send(pid, {:disconnect, :normal})
      send(pid, {:tcp_closed, :socket})

      Process.sleep(50)
      assert Process.alive?(pid)
    end
  end

  # ===================================================================
  # SECTION 2: USERDATASTREAM LISTENKEY LIFECYCLE & RENEWAL STRESS
  # ===================================================================

  describe "UserDataStream listenKey Lifecycle & Keep-Alive Failure Resilience" do
    test "Spot listenKey creation, keep-alive, and close HTTP calls" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/userDataStream"
        Req.Test.json(conn, %{"listenKey" => "spot_listen_key_abc123"})
      end)

      opts = [req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]]
      assert {:ok, "spot_listen_key_abc123"} = UserDataStream.create_listen_key(:spot, opts)

      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v3/userDataStream"
        assert conn.query_string =~ "listenKey=spot_listen_key_abc123"
        Req.Test.json(conn, %{})
      end)

      assert {:ok, %{}} = UserDataStream.keep_alive_listen_key(:spot, "spot_listen_key_abc123", opts)

      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v3/userDataStream"
        assert conn.query_string =~ "listenKey=spot_listen_key_abc123"
        Req.Test.json(conn, %{})
      end)

      assert {:ok, %{}} = UserDataStream.close_listen_key(:spot, "spot_listen_key_abc123", opts)
    end

    test "Futures listenKey creation, keep-alive, and close HTTP calls" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/fapi/v1/listenKey"
        Req.Test.json(conn, %{"listenKey" => "futures_listen_key_xyz789"})
      end)

      opts = [req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]]
      assert {:ok, "futures_listen_key_xyz789"} = UserDataStream.create_listen_key(:futures, opts)

      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/fapi/v1/listenKey"
        assert conn.query_string =~ "listenKey=futures_listen_key_xyz789"
        Req.Test.json(conn, %{})
      end)

      assert {:ok, %{}} = UserDataStream.keep_alive_listen_key(:futures, "futures_listen_key_xyz789", opts)

      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/fapi/v1/listenKey"
        assert conn.query_string =~ "listenKey=futures_listen_key_xyz789"
        Req.Test.json(conn, %{})
      end)

      assert {:ok, %{}} = UserDataStream.close_listen_key(:futures, "futures_listen_key_xyz789", opts)
    end

    test "UserDataStream GenServer initialization failure when listenKey creation fails" do
      plug_fn = fn conn ->
        json_error(conn, %{"code" => -2014, "msg" => "API-key format invalid"}, 400)
      end

      opts = [
        market_type: :spot,
        api_key: "invalid_key",
        req_options: [plug: plug_fn]
      ]

      Process.flag(:trap_exit, true)
      assert {:error, %{status: 400, body: %{"code" => -2014}}} = UserDataStream.start_link(opts)
    end

    test "UserDataStream keep-alive failure handling when PUT request returns error" do
      owner = self()
      plug_fn = fn conn ->
        case conn.method do
          "POST" ->
            Req.Test.json(conn, %{"listenKey" => "expired_listen_key_456"})

          "PUT" ->
            json_error(conn, %{"code" => -1125, "msg" => "This listenKey does not exist."}, 400)

          "DELETE" ->
            Req.Test.json(conn, %{})
        end
      end

      opts = [
        subscriber: owner,
        market_type: :spot,
        api_key: "valid_key",
        req_options: [plug: plug_fn]
      ]

      {:ok, pid} = UserDataStream.start_link(opts)
      assert_receive {:listen_key_created, "expired_listen_key_456"}, 1000

      send(pid, :keep_alive)
      Process.sleep(50)

      # EMPIRICAL OBSERVATION: GenServer process remains running even when keepalive PUT fails
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "UserDataStream teardown close request failure handling during terminate" do
      owner = self()
      plug_fn = fn conn ->
        case conn.method do
          "POST" ->
            Req.Test.json(conn, %{"listenKey" => "listen_key_teardown_test"})

          "DELETE" ->
            json_error(conn, %{"code" => -1001, "msg" => "Internal error"}, 500)
        end
      end

      opts = [
        subscriber: owner,
        market_type: :spot,
        api_key: "valid_key",
        req_options: [plug: plug_fn]
      ]

      {:ok, pid} = UserDataStream.start_link(opts)
      assert_receive {:listen_key_created, "listen_key_teardown_test"}, 1000

      assert :ok == GenServer.stop(pid)
    end
  end

  # ===================================================================
  # SECTION 3: PRISM INPUT SCHEMAS & BOUNDARY VALUES ADVERSARIAL STRESS
  # ===================================================================

  describe "SpotOrderPrism Input Schema & Boundary Stress Testing" do
    test "SpotOrderPrism missing secret_key returns {:error, :missing_secret_key}" do
      input = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        price: 95000.0,
        quantity: 0.01
      }

      assert {:error, :missing_secret_key} == SpotOrderPrism.run(input)
    end

    test "SpotOrderPrism missing mandatory symbol parameter sent to API" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/order"
        refute conn.query_string =~ "symbol="
        json_error(conn, %{"code" => -1102, "msg" => "Mandatory parameter 'symbol' was not sent, was empty/null, or malformed."}, 400)
      end)

      input = %{
        side: "BUY",
        type: "LIMIT",
        quantity: 0.01,
        price: 95000.0,
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -1102}}} = SpotOrderPrism.run(input)
    end

    test "SpotOrderPrism invalid side, invalid type, and negative quantity/price values" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        assert conn.query_string =~ "side=INVALID_SIDE"
        assert conn.query_string =~ "quantity=-0.05"
        json_error(conn, %{"code" => -1100, "msg" => "Illegal characters found in a parameter."}, 400)
      end)

      input_invalid = %{
        symbol: "BTCUSDT",
        side: "INVALID_SIDE",
        type: "LIMIT",
        timeInForce: "GTC",
        quantity: -0.05,
        price: -95000.0,
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -1100}}} = SpotOrderPrism.run(input_invalid)
    end

    test "SpotOrderPrism boundary value handling: zero quantity and extreme numerical values" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        assert conn.query_string =~ "quantity=0"
        assert conn.query_string =~ "price=1.0e30"
        json_error(conn, %{"code" => -1013, "msg" => "Filter failure: MIN_NOTIONAL"}, 400)
      end)

      input_boundary = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        timeInForce: "GTC",
        quantity: 0,
        price: 1.0e30,
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -1013}}} = SpotOrderPrism.run(input_boundary)
    end

    test "SpotOrderPrism nil value handling: nil parameters are excluded from query params" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        refute conn.query_string =~ "symbol="
        refute conn.query_string =~ "quantity="
        json_error(conn, %{"code" => -1100, "msg" => "Illegal characters found in a parameter."}, 400)
      end)

      input_nil = %{
        symbol: nil,
        side: "BUY",
        type: "LIMIT",
        quantity: nil,
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -1100}}} = SpotOrderPrism.run(input_nil)
    end

    test "SpotOrderPrism non-primitive type handling: map input formatted without crash" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        assert conn.query_string =~ "quantity="
        json_error(conn, %{"code" => -1100, "msg" => "Illegal characters found in a parameter."}, 400)
      end)

      input_map_value = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: %{complex: 123},
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -1100}}} = SpotOrderPrism.run(input_map_value)
    end
  end

  describe "FuturesOrderPrism Input Schema & Boundary Stress Testing" do
    test "FuturesOrderPrism missing secret_key returns {:error, :missing_secret_key}" do
      input = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: 0.01,
        price: 95000.0
      }

      assert {:error, :missing_secret_key} == FuturesOrderPrism.run(input)
    end

    test "FuturesOrderPrism missing mandatory side and type parameters sent to API" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/fapi/v1/order"
        assert conn.query_string =~ "symbol=BTCUSDT"
        refute conn.query_string =~ "side="
        refute conn.query_string =~ "type="
        json_error(conn, %{"code" => -1102, "msg" => "Mandatory parameter 'side' was not sent, was empty/null, or malformed."}, 400)
      end)

      input = %{
        symbol: "BTCUSDT",
        quantity: 0.01,
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -1102}}} = FuturesOrderPrism.run(input)
    end

    test "FuturesOrderPrism invalid positionSide, invalid type, negative values, and reduceOnly flag" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        assert conn.query_string =~ "positionSide=INVALID_POS"
        assert conn.query_string =~ "reduceOnly=true"
        assert conn.query_string =~ "quantity=-10.0"
        json_error(conn, %{"code" => -1100, "msg" => "Illegal characters found in a parameter."}, 400)
      end)

      input = %{
        symbol: "BTCUSDT",
        side: "BUY",
        positionSide: "INVALID_POS",
        type: "STOP_MARKET",
        reduceOnly: true,
        quantity: -10.0,
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -1100}}} = FuturesOrderPrism.run(input)
    end

    test "FuturesOrderPrism non-primitive type handling: map input formatted without crash" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "POST"
        assert conn.query_string =~ "quantity="
        json_error(conn, %{"code" => -1100, "msg" => "Illegal characters found in a parameter."}, 400)
      end)

      input_map_value = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: %{complex: 456},
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -1100}}} = FuturesOrderPrism.run(input_map_value)
    end
  end

  describe "Spot & Futures Cancel, Account, OpenOrders & Position Prisms Input Stress" do
    test "SpotCancelOrderPrism missing orderId or origClientOrderId" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v3/order"
        assert conn.query_string =~ "symbol=BTCUSDT"
        refute conn.query_string =~ "orderId="
        json_error(conn, %{"code" => -1102, "msg" => "Either orderId or origClientOrderId must be sent."}, 400)
      end)

      input = %{
        symbol: "BTCUSDT",
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -1102}}} = SpotCancelOrderPrism.run(input)
    end

    test "FuturesCancelOrderPrism invalid negative orderId" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/fapi/v1/order"
        assert conn.query_string =~ "orderId=-999"
        json_error(conn, %{"code" => -2011, "msg" => "Unknown order sent."}, 400)
      end)

      input = %{
        symbol: "BTCUSDT",
        orderId: -999,
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:error, %{status: 400, body: %{"code" => -2011}}} = FuturesCancelOrderPrism.run(input)
    end

    test "SpotAccountPrism and FuturesAccountPrism missing secret_key return missing_secret_key" do
      input = %{}
      assert {:error, :missing_secret_key} == SpotAccountPrism.run(input)
      assert {:error, :missing_secret_key} == FuturesAccountPrism.run(input)
    end

    test "SpotOpenOrdersPrism parameter extraction observation" do
      Req.Test.expect(Lux.Binance.AdversarialStressTest, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/openOrders"
        assert conn.query_string =~ "symbol=BTCUSDT"
        Req.Test.json(conn, [])
      end)

      input = %{
        symbol: "BTCUSDT",
        extra_param: "unexpected",
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Binance.AdversarialStressTest}]
      }

      assert {:ok, []} == SpotOpenOrdersPrism.run(input)
    end
  end
end
