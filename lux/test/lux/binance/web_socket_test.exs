defmodule Lux.Binance.WebSocketTest do
  use ExUnit.Case, async: true
  alias Lux.Binance.WebSocket.Client
  alias Lux.Binance.WebSocket.UserDataStream

  setup do
    Req.Test.verify_on_exit!()
  end

  def start_mock_server(test_pid \\ nil) do
    case :gen_tcp.listen(0, [:binary, packet: :raw, active: false, reuseaddr: true]) do
      {:ok, listen_socket} ->
        {:ok, port} = :inet.port(listen_socket)

        Task.start(fn ->
          mock_server_loop(listen_socket, test_pid)
        end)

        {:ok, port}
      error -> error
    end
  end

  defp mock_server_loop(listen_socket, test_pid) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        Task.start(fn -> handle_mock_client(socket, test_pid) end)
        mock_server_loop(listen_socket, test_pid)
      _ -> :ok
    end
  end

  defp handle_mock_client(socket, test_pid) do
    case :gen_tcp.recv(socket, 0, 2000) do
      {:ok, req} ->
        if test_pid do
          case Regex.run(~r/GET\s+([^\s]+)\s+HTTP/i, req) do
            [_, path] -> send(test_pid, {:mock_server_connected, path})
            _ -> :ok
          end
        end

        case Regex.run(~r/Sec-WebSocket-Key:\s*([^\r\n]+)/i, req) do
          [_, key] ->
            accept_key = :crypto.hash(:sha, key <> "258EAFA5-E914-47DA-95CA-C5AB0DC85B11") |> Base.encode64()
            resp = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: #{accept_key}\r\n\r\n"
            :gen_tcp.send(socket, resp)
            
            # Send a synthetic frame to prove the connection received data
            frame = <<129, 21, 123, 34, 101, 34, 58, 34, 112, 114, 105, 118, 97, 116, 101, 95, 101, 118, 101, 110, 116, 34, 125>>
            :gen_tcp.send(socket, frame)
            
            keep_socket_open(socket)
          _ -> :gen_tcp.close(socket)
        end
      _ -> :gen_tcp.close(socket)
    end
  end

  defp keep_socket_open(socket) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, _} -> keep_socket_open(socket)
      _ -> :gen_tcp.close(socket)
    end
  end

  describe "WebSocket.Client" do
    setup do
      {:ok, port} = start_mock_server()
      %{mock_url: "ws://127.0.0.1:#{port}"}
    end

    test "starts client and handles subscriptions and stream events", %{mock_url: mock_url} do
      {:ok, pid} = Client.start_link(subscriber: self(), streams: ["btcusdt@trade"], url: mock_url)

      assert_receive {:ws_subscribed, %{"method" => "SUBSCRIBE"}}, 1000

      assert :ok == Client.subscribe(pid, "ethusdt@ticker")
      assert_receive {:ws_subscribed, %{"params" => ["ethusdt@ticker"]}}, 3000

      # Dispatch synthetic trade frame
      trade_frame = Jason.encode!(%{
        "e" => "trade",
        "E" => 1672515782136,
        "s" => "BTCUSDT",
        "t" => 12345,
        "p" => "95000.00",
        "q" => "0.05"
      })

      Client.handle_incoming_frame(pid, trade_frame)

      assert_receive {:ws_event, %{"e" => "trade", "s" => "BTCUSDT"}}, 3000
      assert_receive {:signal, %Lux.Signal{payload: %{"p" => "95000.00"}}}, 3000
    end

    test "handles corrupted JSON frame without process termination", %{mock_url: mock_url} do
      {:ok, pid} = Client.start_link(subscriber: self(), url: mock_url)
      Client.handle_incoming_frame(pid, "INVALID_RAW_JSON{{{")

      assert Process.alive?(pid)
    end
  end

  describe "WebSocket.UserDataStream" do
    test "creates and closes listenKey via HTTP requests" do
      Req.Test.expect(Lux.Binance.WebSocketTest, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/userDataStream"
        Req.Test.json(conn, %{"listenKey" => "mock_listen_key_123"})
      end)

      opts = [req_options: [plug: {Req.Test, Lux.Binance.WebSocketTest}]]
      assert {:ok, "mock_listen_key_123"} = UserDataStream.create_listen_key(:spot, opts)

      Req.Test.expect(Lux.Binance.WebSocketTest, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/api/v3/userDataStream"
        assert conn.query_string =~ "listenKey=mock_listen_key_123"
        Req.Test.json(conn, %{})
      end)

      assert {:ok, %{}} = UserDataStream.keep_alive_listen_key(:spot, "mock_listen_key_123", opts)
    end

    test "creates listenKey for futures and connects to private socket" do
      {:ok, port} = start_mock_server(self())
      mock_url = "ws://127.0.0.1:#{port}"

      plug_fn = fn conn ->
        assert conn.request_path == "/fapi/v1/listenKey"
        case conn.method do
          "POST" -> Req.Test.json(conn, %{"listenKey" => "mock_futures_listen_key_456"})
          "DELETE" -> Req.Test.json(conn, %{})
          "PUT" -> Req.Test.json(conn, %{})
        end
      end

      opts = [
        req_options: [plug: plug_fn],
        market_type: :futures,
        api_key: "dummy_key",
        ws_base_url: mock_url,
        subscriber: self()
      ]

      assert {:ok, pid} = UserDataStream.start_link(opts)

      assert_receive {:listen_key_created, "mock_futures_listen_key_456"}, 1000
      
      # Assert the mock server received the correct path with listenKey
      assert_receive {:mock_server_connected, "/mock_futures_listen_key_456"}, 1000
      
      # Assert the synthetic private frame is received
      assert_receive {:ws_event, %{"e" => "private_event"}}, 1000

      state = :sys.get_state(pid)
      assert Process.alive?(state.ws_pid)
      assert state.listen_key == "mock_futures_listen_key_456"
      assert state.market_type == :futures
      
      # Test keep-alive failure triggers reconnection
      plug_fn_fail = fn conn ->
        assert conn.request_path == "/fapi/v1/listenKey"
        case conn.method do
          "PUT" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(400, Jason.encode!(%{"code" => -1125, "msg" => "This listenKey does not exist."}))
          "POST" ->
            Req.Test.json(conn, %{"listenKey" => "mock_reconnected_key_789"})
        end
      end
      
      :sys.replace_state(pid, fn state -> %{state | req_options: [plug: plug_fn_fail]} end)
      send(pid, :keep_alive)
      
      assert_receive {:listen_key_created, "mock_reconnected_key_789"}, 1000
      assert_receive {:mock_server_connected, "/mock_reconnected_key_789"}, 1000
      assert_receive {:ws_event, %{"e" => "private_event"}}, 1000
    end
  end
end
