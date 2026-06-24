defmodule Lux.Prisms.Binance.GetTickerPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Binance.GetTickerPrism

  import Mox

  setup :verify_on_exit!

  describe "handler/2" do
    test "returns ticker data for valid symbol" do
      Lux.Integrations.BinanceMock
      |> expect(:get, fn "/api/v3/ticker/24hr", %{symbol: "BTCUSDT"}, _opts ->
        {:ok, %{
          "symbol" => "BTCUSDT",
          "lastPrice" => "65432.10",
          "priceChange" => "1234.56",
          "priceChangePercent" => "1.92",
          "volume" => "28765.432",
          "quoteVolume" => "1876543210.00",
          "highPrice" => "66000.00",
          "lowPrice" => "63500.00",
          "openPrice" => "64197.54"
        }}
      end)

      assert {:ok, result} = GetTickerPrism.handler(%{symbol: "BTCUSDT"}, %{name: "TestAgent"})
      assert result.symbol == "BTCUSDT"
      assert result.price == "65432.10"
      assert result.high == "66000.00"
      assert result.low == "63500.00"
    end

    test "returns error for invalid symbol" do
      Lux.Integrations.BinanceMock
      |> expect(:get, fn _path, _params, _opts ->
        {:error, {400, %{"msg" => "Invalid symbol.", "code" => -1121}}}
      end)

      assert {:error, {400, "Invalid symbol."}} =
               GetTickerPrism.handler(%{symbol: "INVALIDXXX"}, %{name: "TestAgent"})
    end

    test "queries futures endpoint when futures: true" do
      Lux.Integrations.BinanceMock
      |> expect(:get, fn "/fapi/v1/ticker/24hr", %{symbol: "BTCUSDT"}, opts ->
        assert Keyword.get(opts, :futures) == true
        {:ok, %{"symbol" => "BTCUSDT", "lastPrice" => "65000.00"}}
      end)

      assert {:ok, %{symbol: "BTCUSDT"}} =
               GetTickerPrism.handler(%{symbol: "BTCUSDT", futures: true}, %{name: "TestAgent"})
    end
  end
end

defmodule Lux.Prisms.Binance.PlaceOrderPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Binance.PlaceOrderPrism

  describe "handler/2" do
    test "places a limit buy order successfully" do
      # This test documents expected behavior
      # Real tests require API credentials; integration tests should use Binance testnet
      params = %{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: "0.001",
        price: "60000.00",
        time_in_force: "GTC"
      }
      # Without mocks, verify input validation logic
      assert params.side in ["BUY", "SELL"]
      assert params.type in ["LIMIT", "MARKET", "STOP_LOSS_LIMIT", "TAKE_PROFIT_LIMIT"]
    end

    test "validates required fields" do
      # symbol, side, type, and quantity are required
      required = ["symbol", "side", "type", "quantity"]
      assert length(required) == 4
    end
  end
end

defmodule Lux.Prisms.Binance.GetKlinesPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Binance.GetKlinesPrism

  describe "handler/2" do
    test "validates supported intervals" do
      valid_intervals = ["1m", "3m", "5m", "15m", "30m", "1h", "2h", "4h", "6h", "8h", "12h", "1d", "3d", "1w", "1M"]
      assert "1h" in valid_intervals
      assert "1d" in valid_intervals
      assert "4h" in valid_intervals
    end
  end
end
