defmodule Lux.Prisms.Binance.FuturesPrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Binance.FuturesAccountPrism
  alias Lux.Prisms.Binance.FuturesCancelOrderPrism
  alias Lux.Prisms.Binance.FuturesOrderPrism
  alias Lux.Prisms.Binance.FuturesPositionPrism

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "FuturesAccountPrism" do
    test "retrieves Futures account summary" do
      Req.Test.expect(Lux.Prisms.Binance.FuturesPrismsTest, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/fapi/v2/account"
        assert conn.query_string =~ "signature="
        Req.Test.json(conn, %{"totalWalletBalance" => "1000.00000000", "positions" => []})
      end)

      input = %{
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Prisms.Binance.FuturesPrismsTest}]
      }

      assert {:ok, %{"totalWalletBalance" => "1000.00000000"}} = FuturesAccountPrism.run(input)
    end
  end

  describe "FuturesOrderPrism" do
    test "places a new Futures LIMIT order" do
      Req.Test.expect(Lux.Prisms.Binance.FuturesPrismsTest, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/fapi/v1/order"
        assert conn.query_string =~ "symbol=BTCUSDT"
        assert conn.query_string =~ "signature="
        Req.Test.json(conn, %{"orderId" => 987654, "status" => "NEW", "symbol" => "BTCUSDT"})
      end)

      input = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        timeInForce: "GTC",
        quantity: "0.01",
        price: "95000.00",
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Prisms.Binance.FuturesPrismsTest}]
      }

      assert {:ok, %{"orderId" => 987654, "status" => "NEW"}} = FuturesOrderPrism.run(input)
    end
  end

  describe "FuturesPositionPrism" do
    test "queries position risk details" do
      Req.Test.expect(Lux.Prisms.Binance.FuturesPrismsTest, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/fapi/v2/positionRisk"
        assert conn.query_string =~ "symbol=BTCUSDT"
        assert conn.query_string =~ "signature="
        Req.Test.json(conn, [%{"symbol" => "BTCUSDT", "positionAmt" => "0.000", "leverage" => "20"}])
      end)

      input = %{
        symbol: "BTCUSDT",
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Prisms.Binance.FuturesPrismsTest}]
      }

      assert {:ok, [%{"symbol" => "BTCUSDT", "leverage" => "20"}]} = FuturesPositionPrism.run(input)
    end
  end

  describe "FuturesCancelOrderPrism" do
    test "cancels active Futures order" do
      Req.Test.expect(Lux.Prisms.Binance.FuturesPrismsTest, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/fapi/v1/order"
        assert conn.query_string =~ "symbol=BTCUSDT"
        assert conn.query_string =~ "orderId=987654"
        assert conn.query_string =~ "signature="
        Req.Test.json(conn, %{"orderId" => 987654, "status" => "CANCELED", "symbol" => "BTCUSDT"})
      end)

      input = %{
        symbol: "BTCUSDT",
        orderId: 987654,
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Prisms.Binance.FuturesPrismsTest}]
      }

      assert {:ok, %{"orderId" => 987654, "status" => "CANCELED"}} = FuturesCancelOrderPrism.run(input)
    end
  end
end
