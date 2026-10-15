defmodule Lux.Web3.Exchanges.HyperliquidTest do
  use ExUnit.Case, async: false

  alias Lux.Prisms.Web3.HyperliquidPrism
  alias Lux.Web3.Exchanges.Hyperliquid

  @wallet "0x8200000000000000000000000000000000000082"

  setup do
    Hyperliquid.reset_state!()
    :ok
  end

  describe "perpetual markets and L2 orderbook feed" do
    test "lists perpetual markets and fetches L2 orderbook depth" do
      assert {:ok, markets} = Hyperliquid.list_markets()
      assert length(markets) >= 4
      assert Enum.any?(markets, &(&1.coin == "BTC" and &1.max_leverage == 50))

      assert {:ok, book} = Hyperliquid.get_l2_orderbook("ETH", levels: 4)
      assert book.coin == "ETH"
      assert length(book.bids) == 4
      assert length(book.asks) == 4
      assert hd(book.asks).price > hd(book.bids).price
    end
  end

  describe "leverage and margin management" do
    test "configures leverage and isolated margin collateral" do
      assert {:ok, lev} = Hyperliquid.set_leverage(@wallet, "BTC", 20, :isolated)
      assert lev.leverage == 20
      assert lev.margin_mode == :isolated

      assert {:error, :exceeds_max_leverage} =
               Hyperliquid.set_leverage(@wallet, "SOL", 50, :cross)

      {:ok, _fill} =
        Hyperliquid.place_order(@wallet, %{
          coin: "BTC",
          side: :buy,
          size: 0.5,
          order_type: :market
        })

      assert {:ok, updated_pos} = Hyperliquid.update_isolated_margin(@wallet, "BTC", 1_000.0)
      assert updated_pos.isolated_margin == 2_700.0
    end
  end

  describe "order placement, cancellation, and TWAP execution" do
    test "executes market and TWAP orders and manages resting limit/trigger orders" do
      assert {:ok, mkt_order} =
               Hyperliquid.place_order(@wallet, %{
                 coin: "ETH",
                 side: :buy,
                 size: 2.0,
                 order_type: :market
               })

      assert mkt_order.status == :filled
      assert mkt_order.fill_price == 3_000.0

      assert {:ok, resting_limit} =
               Hyperliquid.place_order(@wallet, %{
                 coin: "ETH",
                 side: :buy,
                 size: 1.0,
                 order_type: :limit,
                 price: 2_850.0
               })

      assert resting_limit.status == :resting

      assert {:ok, stop_order} =
               Hyperliquid.place_order(@wallet, %{
                 coin: "ETH",
                 side: :sell,
                 size: 1.0,
                 order_type: :trigger,
                 trigger_price: 2_750.0,
                 reduce_only: true
               })

      assert stop_order.status == :resting

      assert {:ok, open_orders} = Hyperliquid.list_open_orders(@wallet, coin: "ETH")
      assert length(open_orders) == 2

      assert {:ok, canceled} = Hyperliquid.cancel_order(@wallet, resting_limit.order_id)
      assert canceled.status == :canceled

      assert {:ok, twap} =
               Hyperliquid.place_order(@wallet, %{
                 coin: "SOL",
                 side: :buy,
                 size: 20.0,
                 order_type: :twap,
                 slices: 4,
                 duration_minutes: 60
               })

      assert twap.order_type == :twap
      assert twap.executed_slice_size == 5.0
      assert twap.remaining_size == 15.0
    end
  end

  describe "position tracking, PnL, and liquidation protection" do
    test "tracks unrealized/realized PnL, liquidation price, and auto-deleverages critical positions" do
      {:ok, _} = Hyperliquid.set_leverage(@wallet, "ETH", 20, :isolated)

      {:ok, _} =
        Hyperliquid.place_order(@wallet, %{
          coin: "ETH",
          side: :buy,
          size: 5.0,
          order_type: :market
        })

      {:ok, _} = Hyperliquid.update_market_price("ETH", 3_150.0)
      {:ok, state} = Hyperliquid.get_user_state(@wallet)
      [eth_pos] = state.positions
      assert eth_pos.unrealized_pnl == 750.0
      assert eth_pos.roe_pct > 0.0

      {:ok, _} = Hyperliquid.update_market_price("ETH", 2_920.0)

      assert {:ok, risk} =
               Hyperliquid.assess_risk_and_protect(@wallet,
                 auto_protect: true,
                 critical_distance_pct: 6.0
               )

      assert risk.overall_risk_status == :critical
      [eth_risk] = risk.position_risks
      assert eth_risk.protective_action.action == :auto_deleveraged_50_pct
      assert eth_risk.protective_action.size_closed == 2.5

      {:ok, post_state} = Hyperliquid.get_user_state(@wallet)
      [reduced_pos] = post_state.positions
      assert reduced_pos.size == 2.5
    end
  end

  describe "HyperliquidPrism handler" do
    test "dispatches Hyperliquid actions via Prism interface" do
      assert {:ok, %{status: "ok", data: %{markets: markets}}} =
               HyperliquidPrism.handler(%{action: "list_markets"}, %{})

      assert length(markets) >= 4

      assert {:ok, %{status: "ok", data: order}} =
               HyperliquidPrism.handler(
                 %{
                   action: "place_order",
                   wallet: @wallet,
                   coin: "BTC",
                   side: "buy",
                   size: 0.1,
                   order_type: "market"
                 },
                 %{}
               )

      assert order.status == :filled

      assert {:ok, %{status: "ok", data: state}} =
               HyperliquidPrism.handler(%{action: "get_user_state", wallet: @wallet}, %{})

      assert length(state.positions) == 1
    end
  end
end
