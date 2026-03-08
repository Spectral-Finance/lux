defmodule Lux.Integrations.Binance.ClientTest do
  use UnitAPICase, async: true
  alias Lux.Integrations.Binance.Client

  @api_key "test-binance-api-key"
  @secret_key "test-binance-secret-key"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "public endpoints" do
    test "GET request with params" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/ticker/price"
        assert conn.query_string =~ "symbol=BTCUSDT"
        assert Plug.Conn.get_req_header(conn, "x-mbx-apikey") == [@api_key]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"symbol" => "BTCUSDT", "price" => "50000.00"}))
      end)

      assert {:ok, %{"symbol" => "BTCUSDT", "price" => "50000.00"}} =
        Client.request(:get, "/api/v3/ticker/price", %{
          params: %{symbol: "BTCUSDT"}, api_key: @api_key,
          plug: {Req.Test, BinanceClientMock}
        })
    end

    test "handles 400 error" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"code" => -1121, "msg" => "Invalid symbol."}))
      end)

      assert {:error, {400, "Invalid symbol."}} =
        Client.request(:get, "/api/v3/ticker/price", %{
          params: %{symbol: "INVALID"}, api_key: @api_key,
          plug: {Req.Test, BinanceClientMock}
        })
    end

    test "handles rate limit (429)" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"msg" => "Too many requests."}))
      end)

      assert {:error, {:rate_limited, "Too many requests."}} =
        Client.request(:get, "/api/v3/ticker/price", %{
          api_key: @api_key, plug: {Req.Test, BinanceClientMock}
        })
    end

    test "handles IP ban (418)" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(418, Jason.encode!(%{"msg" => "IP banned."}))
      end)

      assert {:error, {:ip_banned, "IP banned."}} =
        Client.request(:get, "/api/v3/ticker/price", %{
          api_key: @api_key, plug: {Req.Test, BinanceClientMock}
        })
    end
  end

  describe "signed endpoints" do
    test "adds timestamp and signature" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.query_string =~ "timestamp="
        assert conn.query_string =~ "signature="
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"balances" => []}))
      end)

      assert {:ok, %{"balances" => []}} =
        Client.request(:get, "/api/v3/account", %{
          signed: true, api_key: @api_key, secret_key: @secret_key,
          plug: {Req.Test, BinanceClientMock}
        })
    end
  end

  describe "futures endpoints" do
    test "uses futures path" do
      Req.Test.expect(BinanceClientMock, fn conn ->
        assert conn.request_path == "/fapi/v1/ticker/price"
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"symbol" => "BTCUSDT", "price" => "50000.00"}))
      end)

      assert {:ok, _} =
        Client.request(:get, "/fapi/v1/ticker/price", %{
          params: %{symbol: "BTCUSDT"}, futures: true, api_key: @api_key,
          plug: {Req.Test, BinanceClientMock}
        })
    end
  end
end
