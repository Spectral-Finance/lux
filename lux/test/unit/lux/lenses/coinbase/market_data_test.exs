defmodule Lux.Lenses.Coinbase.MarketDataTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Coinbase.MarketData
  alias Lux.Integrations.Coinbase.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "get_products/1" do
    test "returns formatted products" do
      Req.Test.stub(Client, fn conn ->
        assert conn.request_path == "/api/v3/brokerage/products"
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"products" => [
          %{"product_id" => "BTC-USD", "price" => "50000", "price_percentage_change_24h" => "2.5",
            "volume_24h" => "1000000", "base_currency_id" => "BTC", "quote_currency_id" => "USD", "status" => "online"},
          %{"product_id" => "ETH-USD", "price" => "3000", "price_percentage_change_24h" => "-1",
            "volume_24h" => "500000", "base_currency_id" => "ETH", "quote_currency_id" => "USD", "status" => "online"}
        ]}))
      end)

      assert {:ok, products} = MarketData.get_products()
      assert length(products) == 2
      assert hd(products).product_id == "BTC-USD"
    end
  end

  describe "get_ticker/2" do
    test "returns formatted ticker" do
      Req.Test.stub(Client, fn conn ->
        assert conn.request_path == "/api/v3/brokerage/products/BTC-USD"
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"product_id" => "BTC-USD", "price" => "50000",
          "price_percentage_change_24h" => "2.5", "volume_24h" => "1M", "base_currency_id" => "BTC",
          "quote_currency_id" => "USD", "status" => "online"}))
      end)

      assert {:ok, ticker} = MarketData.get_ticker("BTC-USD")
      assert ticker.product_id == "BTC-USD"
      assert ticker.price == "50000"
    end

    test "handles invalid product" do
      Req.Test.stub(Client, fn conn ->
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"error" => "NOT_FOUND", "message" => "Not found"}))
      end)

      assert {:error, {400, "NOT_FOUND: Not found"}} = MarketData.get_ticker("INVALID")
    end
  end

  describe "get_candles/3" do
    test "returns formatted candles" do
      Req.Test.stub(Client, fn conn ->
        assert conn.request_path == "/api/v3/brokerage/products/BTC-USD/candles"
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"candles" => [
          %{"start" => "1234567890", "open" => "49000", "high" => "51000", "low" => "48500", "close" => "50000", "volume" => "100"},
          %{"start" => "1234567800", "open" => "48000", "high" => "49500", "low" => "47800", "close" => "49000", "volume" => "85"}
        ]}))
      end)

      assert {:ok, candles} = MarketData.get_candles("BTC-USD", %{start: "1234567800", end: "1234567890", granularity: "ONE_HOUR"})
      assert length(candles) == 2
      assert hd(candles).open == "49000"
    end
  end

  describe "get_orderbook/3" do
    test "returns formatted orderbook" do
      Req.Test.stub(Client, fn conn ->
        assert conn.request_path == "/api/v3/brokerage/product_book"
        conn |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"pricebook" => %{
          "product_id" => "BTC-USD",
          "bids" => [%{"price" => "49999", "size" => "0.5"}],
          "asks" => [%{"price" => "50001", "size" => "0.3"}],
          "time" => "2024-01-01T00:00:00Z"
        }}))
      end)

      assert {:ok, book} = MarketData.get_orderbook("BTC-USD")
      assert book.product_id == "BTC-USD"
      assert length(book.bids) == 1
      assert length(book.asks) == 1
    end
  end
end
