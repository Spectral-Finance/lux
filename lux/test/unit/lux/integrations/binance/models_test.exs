defmodule Lux.Integrations.Binance.ModelsTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Binance.Models

  describe "parse_order/1" do
    test "parses a valid spot order from API response" do
      raw = %{
        "orderId" => 123_456,
        "clientOrderId" => "abc123",
        "symbol" => "ETHUSDT",
        "side" => "BUY",
        "type" => "LIMIT",
        "timeInForce" => "GTC",
        "origQty" => "0.10000000",
        "price" => "2800.00000000",
        "status" => "NEW",
        "executedQty" => "0.00000000",
        "cummulativeQuoteQty" => "0.00000000",
        "avgPrice" => nil,
        "time" => 1_678_901_234,
        "updateTime" => 1_678_901_235
      }

      order = Models.parse_order(raw)

      assert order.order_id == 123_456
      assert order.client_order_id == "abc123"
      assert order.symbol == "ETHUSDT"
      assert order.side == "BUY"
      assert order.type == "LIMIT"
      assert order.time_in_force == "GTC"
      assert order.quantity == "0.10000000"
      assert order.price == "2800.00000000"
      assert order.status == "NEW"
      assert order.filled_quantity == "0.00000000"
    end

    test "parses a filled sell order" do
      raw = %{
        "orderId" => 789,
        "symbol" => "BTCUSDT",
        "side" => "SELL",
        "type" => "MARKET",
        "origQty" => "0.50000000",
        "price" => "0.00000000",
        "status" => "FILLED",
        "executedQty" => "0.50000000",
        "cummulativeQuoteQty" => "30000.00000000"
      }

      order = Models.parse_order(raw)

      assert order.order_id == 789
      assert order.symbol == "BTCUSDT"
      assert order.side == "SELL"
      assert order.status == "FILLED"
    end

    test "parses order with snake_case keys" do
      raw = %{
        "order_id" => 42,
        "symbol" => "BNBUSDT",
        "side" => "BUY",
        "type" => "LIMIT",
        "orig_qty" => "1.0",
        "price" => "300.0"
      }

      order = Models.parse_order(raw)

      assert order.order_id == 42
      assert order.quantity == "1.0"
    end
  end

  describe "parse_position/1" do
    test "parses a valid futures position" do
      raw = %{
        "symbol" => "ETHUSDT",
        "positionSide" => "LONG",
        "entryPrice" => "2800.0",
        "markPrice" => "2850.0",
        "positionAmt" => "1.0",
        "leverage" => "5",
        "marginType" => "cross",
        "isolatedWallet" => "0",
        "liquidationPrice" => "1400.0",
        "unRealizedProfit" => "50.0",
        "notional" => "2850.0",
        "initialMargin" => "570.0",
        "maintMargin" => "11.4"
      }

      pos = Models.parse_position(raw)

      assert pos.symbol == "ETHUSDT"
      assert pos.position_side == "LONG"
      assert pos.entry_price == "2800.0"
      assert pos.mark_price == "2850.0"
      assert pos.quantity == "1.0"
      assert pos.leverage == "5"
      assert pos.margin_type == "cross"
      assert pos.liquidation_price == "1400.0"
      assert pos.unrealized_pnl == "50.0"
    end

    test "handles default position side" do
      raw = %{
        "symbol" => "BTCUSDT",
        "entryPrice" => "60000.0",
        "markPrice" => "61000.0",
        "positionAmt" => "-0.5"
      }

      pos = Models.parse_position(raw)

      assert pos.position_side == "BOTH"
      assert pos.quantity == "-0.5"
    end
  end

  describe "parse_balance/1" do
    test "parses a spot balance" do
      raw = %{
        "asset" => "ETH",
        "free" => "1.50000000",
        "locked" => "0.00000000"
      }

      balance = Models.parse_balance(raw)

      assert balance.asset == "ETH"
      assert balance.free == "1.50000000"
      assert balance.locked == "0.00000000"
    end
  end

  describe "parse_account/1" do
    test "parses a spot account response" do
      raw = %{
        "canTrade" => true,
        "canWithdraw" => true,
        "canDeposit" => true,
        "accountType" => "SPOT",
        "balances" => [
          %{"asset" => "ETH", "free" => "1.5", "locked" => "0.0", "total" => "1.5"},
          %{"asset" => "USDT", "free" => "5000.0", "locked" => "0.0", "total" => "5000.0"}
        ]
      }

      account = Models.parse_account(raw)

      assert account.can_trade == true
      assert account.can_withdraw == true
      assert account.account_type == "SPOT"
      assert length(account.balances) == 2
      assert hd(account.balances).asset == "ETH"
    end

    test "parses a futures account response" do
      raw = %{
        "totalWalletBalance" => "10000.0",
        "totalUnrealizedProfit" => "150.0",
        "totalMarginBalance" => "10150.0",
        "availableBalance" => "8000.0",
        "positions" => [
          %{
            "symbol" => "ETHUSDT",
            "positionAmt" => "1.0",
            "entryPrice" => "2800.0",
            "markPrice" => "2850.0",
            "unRealizedProfit" => "50.0"
          }
        ]
      }

      account = Models.parse_account(raw)

      assert account.total_wallet_balance == "10000.0"
      assert account.total_unrealized_pnl == "150.0"
      assert length(account.positions) == 1
    end

    test "handles account with no positions" do
      raw = %{
        "accountType" => "SPOT",
        "balances" => []
      }

      account = Models.parse_account(raw)

      assert account.positions == []
      assert account.balances == []
    end
  end

  describe "parse_market/2" do
    test "parses exchange info for a symbol" do
      raw = %{
        "symbol" => "ETHUSDT",
        "status" => "TRADING",
        "baseAsset" => "ETH",
        "quoteAsset" => "USDT",
        "isSpotTradingAllowed" => true,
        "isMarginTradingAllowed" => true,
        "filters" => [
          %{"filterType" => "PRICE_FILTER", "tickSize" => "0.01000000"},
          %{"filterType" => "LOT_SIZE", "stepSize" => "0.00100000"},
          %{"filterType" => "MIN_NOTIONAL", "minNotional" => "10.00000000"}
        ]
      }

      market = Models.parse_market("ETHUSDT", raw)

      assert market.symbol == "ETHUSDT"
      assert market.status == "TRADING"
      assert market.base_asset == "ETH"
      assert market.quote_asset == "USDT"
      assert market.price_tick_size == "0.01000000"
      assert market.quantity_tick_size == "0.00100000"
      assert market.min_notional == "10.00000000"
      assert market.is_spot_trading_allowed == true
    end

    test "handles missing filters" do
      raw = %{
        "symbol" => "NEWCOINUSDT",
        "status" => "BREAK",
        "baseAsset" => "NEWCOIN",
        "quoteAsset" => "USDT",
        "filters" => []
      }

      market = Models.parse_market("NEWCOINUSDT", raw)

      assert market.price_tick_size == nil
      assert market.quantity_tick_size == nil
    end
  end

  describe "parse_order_book/2" do
    test "parses order book data" do
      raw = %{
        "lastUpdateId" => 123_456_789,
        "bids" => [["2800.00", "1.5"], ["2799.00", "2.0"]],
        "asks" => [["2801.00", "1.0"], ["2802.00", "3.0"]]
      }

      book = Models.parse_order_book("ETHUSDT", raw)

      assert book.symbol == "ETHUSDT"
      assert book.last_update_id == 123_456_789
      assert length(book.bids) == 2
      assert hd(book.bids).price == "2800.00"
      assert hd(book.bids).quantity == "1.5"
      assert length(book.asks) == 2
    end
  end

  describe "parse_ticker/1" do
    test "parses 24hr ticker" do
      raw = %{
        "symbol" => "ETHUSDT",
        "priceChange" => "50.0",
        "priceChangePercent" => "1.786",
        "weightedAvgPrice" => "2825.0",
        "lastPrice" => "2850.0",
        "lastQty" => "2.5",
        "openPrice" => "2800.0",
        "highPrice" => "2900.0",
        "lowPrice" => "2750.0",
        "volume" => "10000.0",
        "quoteVolume" => "28500000.0",
        "openTime" => 1_678_900_000,
        "closeTime" => 1_678_986_400,
        "count" => 12345
      }

      ticker = Models.parse_ticker(raw)

      assert ticker.symbol == "ETHUSDT"
      assert ticker.last_price == "2850.0"
      assert ticker.price_change_pct == "1.786"
      assert ticker.volume == "10000.0"
      assert ticker.count == 12345
    end
  end

  describe "parse_kline/1" do
    test "parses kline array" do
      raw = [
        1_678_901_200_000, "2800.0", "2850.0", "2750.0", "2840.0", "1500.0",
        1_678_904_800_000, "4_275_000.0", 5000, "750.0", "2_137_500.0", "0"
      ]

      kline = Models.parse_kline(raw)

      assert kline.open_time == 1_678_901_200_000
      assert kline.open == "2800.0"
      assert kline.high == "2850.0"
      assert kline.low == "2750.0"
      assert kline.close == "2840.0"
      assert kline.volume == "1500.0"
    end
  end

  describe "parse_trade/1" do
    test "parses a trade" do
      raw = %{
        "id" => 987_654,
        "symbol" => "ETHUSDT",
        "price" => "2800.50",
        "qty" => "0.5",
        "quoteQty" => "1400.25",
        "time" => 1_678_900_000,
        "isBuyerMaker" => false
      }

      trade = Models.parse_trade(raw)

      assert trade.id == 987_654
      assert trade.symbol == "ETHUSDT"
      assert trade.price == "2800.50"
      assert trade.quantity == "0.5"
      assert trade.quote_quantity == "1400.25"
      assert trade.is_buyer_maker == false
    end
  end
end
