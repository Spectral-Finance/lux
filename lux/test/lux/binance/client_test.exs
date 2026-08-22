defmodule Lux.Binance.ClientTest do
  use ExUnit.Case, async: true
  alias Lux.Binance.Client

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "get_base_url/2" do
    test "returns correct mainnet and testnet URLs" do
      assert Client.get_base_url(:spot, false) == "https://api.binance.com"
      assert Client.get_base_url(:spot, true) == "https://testnet.binance.vision/api"
      assert Client.get_base_url(:futures, false) == "https://fapi.binance.com"
      assert Client.get_base_url(:futures, true) == "https://testnet.binancefuture.com"
    end
  end

  describe "request/5 with Req.Test" do
    test "executes GET request to Spot API" do
      Req.Test.expect(Lux.Binance.ClientTest, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/ticker/price"
        assert conn.query_string =~ "symbol=BTCUSDT"
        Req.Test.json(conn, %{"symbol" => "BTCUSDT", "price" => "95120.50"})
      end)

      opts = [req_options: [plug: {Req.Test, Lux.Binance.ClientTest}]]

      assert {:ok, %{"symbol" => "BTCUSDT", "price" => "95120.50"}} =
               Client.request(:get, :spot, "/api/v3/ticker/price", %{symbol: "BTCUSDT"}, opts)
    end

    test "executes signed POST request to Spot API" do
      Req.Test.expect(Lux.Binance.ClientTest, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/order"
        assert conn.query_string =~ "symbol=BTCUSDT"
        assert conn.query_string =~ "signature="

        headers_map = conn.req_headers |> Enum.into(%{})
        assert Map.get(headers_map, "x-mbx-apikey") == "test_api_key"

        Req.Test.json(conn, %{"symbol" => "BTCUSDT", "orderId" => 12345, "status" => "FILLED"})
      end)

      params = [symbol: "BTCUSDT", side: "BUY", type: "MARKET", quantity: "0.1"]

      opts = [
        signed: true,
        api_key: "test_api_key",
        secret_key: "test_secret_key",
        req_options: [plug: {Req.Test, Lux.Binance.ClientTest}]
      ]

      assert {:ok, %{"orderId" => 12345, "status" => "FILLED"}} =
               Client.request(:post, :spot, "/api/v3/order", params, opts)
    end

    test "returns error tuple on HTTP 400 response" do
      Req.Test.expect(Lux.Binance.ClientTest, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"code" => -1102, "msg" => "Mandatory parameter 'symbol' was not sent, was empty/null, or malformed."})
      end)

      opts = [req_options: [plug: {Req.Test, Lux.Binance.ClientTest}]]

      assert {:error, %{status: 400, body: %{"code" => -1102}}} =
               Client.request(:get, :spot, "/api/v3/ticker/price", %{}, opts)
    end

    test "returns missing_secret_key error when signed is true but secret_key is missing" do
      assert {:error, :missing_secret_key} =
               Client.request(:get, :spot, "/api/v3/account", %{}, signed: true, secret_key: nil, api_key: nil)
    end
  end
end
