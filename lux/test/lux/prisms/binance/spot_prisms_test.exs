defmodule Lux.Prisms.Binance.SpotPrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Binance.SpotAccountPrism
  alias Lux.Prisms.Binance.SpotCancelOrderPrism
  alias Lux.Prisms.Binance.SpotOpenOrdersPrism
  alias Lux.Prisms.Binance.SpotOrderPrism

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "SpotAccountPrism" do
    test "retrieves Spot account info" do
      Req.Test.expect(Lux.Prisms.Binance.SpotPrismsTest, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/account"
        assert conn.query_string =~ "signature="
        Req.Test.json(conn, %{"accountType" => "SPOT", "balances" => [%{"asset" => "BTC", "free" => "1.0", "locked" => "0.0"}]})
      end)

      input = %{
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Prisms.Binance.SpotPrismsTest}]
      }

      assert {:ok, %{"accountType" => "SPOT", "balances" => [%{"asset" => "BTC"}]}} =
               SpotAccountPrism.run(input)
    end
  end

  describe "SpotOrderPrism" do
    test "places a new Spot LIMIT order" do
      Req.Test.expect(Lux.Prisms.Binance.SpotPrismsTest, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v3/order"
        assert conn.query_string =~ "symbol=BTCUSDT"
        assert conn.query_string =~ "signature="
        Req.Test.json(conn, %{"orderId" => 123456, "status" => "NEW", "symbol" => "BTCUSDT"})
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
        req_options: [plug: {Req.Test, Lux.Prisms.Binance.SpotPrismsTest}]
      }

      assert {:ok, %{"orderId" => 123456, "status" => "NEW"}} = SpotOrderPrism.run(input)
    end
  end

  describe "SpotCancelOrderPrism" do
    test "cancels active Spot order" do
      Req.Test.expect(Lux.Prisms.Binance.SpotPrismsTest, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/api/v3/order"
        assert conn.query_string =~ "symbol=BTCUSDT"
        assert conn.query_string =~ "orderId=123456"
        assert conn.query_string =~ "signature="
        Req.Test.json(conn, %{"orderId" => 123456, "status" => "CANCELED", "symbol" => "BTCUSDT"})
      end)

      input = %{
        symbol: "BTCUSDT",
        orderId: 123456,
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Prisms.Binance.SpotPrismsTest}]
      }

      assert {:ok, %{"orderId" => 123456, "status" => "CANCELED"}} = SpotCancelOrderPrism.run(input)
    end
  end

  describe "SpotOpenOrdersPrism" do
    test "queries open Spot orders" do
      Req.Test.expect(Lux.Prisms.Binance.SpotPrismsTest, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v3/openOrders"
        assert conn.query_string =~ "symbol=BTCUSDT"
        assert conn.query_string =~ "signature="
        Req.Test.json(conn, [%{"orderId" => 123456, "symbol" => "BTCUSDT", "price" => "95000.00"}])
      end)

      input = %{
        symbol: "BTCUSDT",
        api_key: "test_key",
        secret_key: "test_secret",
        req_options: [plug: {Req.Test, Lux.Prisms.Binance.SpotPrismsTest}]
      }

      assert {:ok, [%{"orderId" => 123456, "symbol" => "BTCUSDT"}]} = SpotOpenOrdersPrism.run(input)
    end
  end
end
