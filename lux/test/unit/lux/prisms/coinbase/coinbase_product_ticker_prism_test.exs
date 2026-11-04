defmodule Lux.Prisms.Coinbase.CoinbaseProductTickerPrismTest do
  use UnitCase, async: false

  alias Lux.Prisms.Coinbase.CoinbaseProductTickerPrism
  alias Lux.Coinbase.Client

  setup do
    Application.put_env(:lux, :coinbase_req_options, plug: {Req.Test, Lux.Coinbase.Client})
    :ok
  end

  describe "handler/2" do
    test "fetches a product ticker without authentication (happy path / regression for issue #83)" do
      ticker = %{
        "product_id" => "BTC-USD",
        "price" => "50000.00",
        "size" => "0.1",
        "trade_id" => "123456"
      }

      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/products/BTC-USD/ticker"
        # Public endpoint: no auth headers required
        assert Plug.Conn.get_req_header(conn, "cb-access-key") == []
        Req.Test.json(conn, ticker)
      end)

      assert {:ok, %{status: "success", ticker: ^ticker}} =
               CoinbaseProductTickerPrism.run(%{"product_id" => "BTC-USD"})
    end
  end

  describe "null input" do
    test "rejects nil without crashing" do
      assert {:error, _reason} = CoinbaseProductTickerPrism.run(nil)
    end

    test "rejects an empty map" do
      assert {:error, _reason} = CoinbaseProductTickerPrism.run(%{})
    end
  end

  describe "empty input" do
    test "rejects an empty product_id" do
      assert {:error, _reason} = CoinbaseProductTickerPrism.run(%{"product_id" => ""})
    end

    test "rejects a whitespace-only product_id" do
      assert {:error, _reason} =
               CoinbaseProductTickerPrism.run(%{"product_id" => "  \t  "})
    end
  end

  describe "boundary limits" do
    test "accepts product ids with the standard symbol format" do
      for product_id <- ["BTC-USD", "ETH-USD", "SOL-USD"] do
        Req.Test.expect(Lux.Coinbase.Client, fn conn ->
          assert conn.request_path == "/products/#{product_id}/ticker"
          Req.Test.json(conn, %{"product_id" => product_id})
        end)

        assert {:ok, %{status: "success"}} =
                 CoinbaseProductTickerPrism.run(%{"product_id" => product_id})
      end
    end
  end

  describe "negative / failure" do
    test "rejects a non-string product_id" do
      assert {:error, _reason} = CoinbaseProductTickerPrism.run(%{"product_id" => 123})
    end

    test "propagates upstream errors without crashing" do
      Req.Test.expect(Lux.Coinbase.Client, fn conn ->
        conn = Plug.Conn.put_status(conn, 404)
        Req.Test.json(conn, %{"message" => "Not Found"})
      end)

      assert {:error, %{"status" => 404}} =
               CoinbaseProductTickerPrism.run(%{"product_id" => "INVALID-USD"})
    end
  end
end
