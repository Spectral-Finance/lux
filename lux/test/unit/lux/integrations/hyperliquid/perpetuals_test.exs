defmodule Lux.Integrations.Hyperliquid.PerpetualsTest do
  use UnitCase, async: true

  alias Lux.Integrations.Hyperliquid.Perpetuals

  @position %{
    coin: "ETH",
    size: 2.0,
    entry_px: 3_000.0,
    mark_px: 3_200.0,
    liquidation_px: 2_700.0,
    margin_used: 1_200.0,
    leverage: 5.0
  }

  describe "info_request/2" do
    test "builds Hyperliquid info request plans" do
      assert {:ok, meta} = Perpetuals.info_request(:meta)
      assert meta.method == :post
      assert meta.endpoint == "/info"
      assert meta.payload == %{type: "meta"}

      assert {:ok, state} = Perpetuals.info_request(:clearinghouse_state, %{user: "0xabc"})
      assert state.payload == %{type: "clearinghouseState", user: "0xabc"}
    end
  end

  describe "order_plan/1" do
    test "builds safe order action payloads" do
      assert {:ok, order} =
               Perpetuals.order_plan(%{
                 coin: "ETH",
                 side: :buy,
                 size: 1.5,
                 limit_px: 3_100,
                 reduce_only: true,
                 idempotency_key: "order-1"
               })

      assert order.action == :order
      assert order.payload.coin == "ETH"
      assert order.payload.is_buy == true
      assert order.payload.sz == 1.5
      assert order.payload.limit_px == 3_100.0
      assert order.payload.reduce_only == true
      assert order.idempotency_key == "order-1"
    end

    test "rejects invalid orders" do
      assert Perpetuals.order_plan(%{side: :buy, size: 1}) ==
               {:error, "Missing Hyperliquid market coin"}

      assert Perpetuals.order_plan(%{coin: "ETH", side: :hold, size: 1}) ==
               {:error, "Unsupported Hyperliquid order side"}

      assert Perpetuals.order_plan(%{coin: "ETH", side: :buy, size: 0}) ==
               {:error, "Order size must be positive"}
    end
  end

  describe "position_snapshot/1" do
    test "normalizes long and short positions with PnL" do
      long = Perpetuals.position_snapshot(@position)
      assert long.side == :long
      assert long.unrealized_pnl == 400.0
      assert_in_delta long.roe, 0.3333, 0.0001

      short = Perpetuals.position_snapshot(%{@position | size: -2.0, mark_px: 2_800.0})
      assert short.side == :short
      assert short.unrealized_pnl == 400.0
    end
  end

  describe "liquidation_buffer/1 and risk_decision/2" do
    test "classifies liquidation severity and policy decisions" do
      healthy = Perpetuals.liquidation_buffer(@position)
      assert healthy.severity == :healthy
      assert_in_delta healthy.distance_ratio, 0.15625, 0.0001

      assert Perpetuals.risk_decision(@position, %{
               max_leverage: 6,
               min_liquidation_buffer: 0.1
             }).allowed? == true

      assert Perpetuals.risk_decision(%{@position | leverage: 12}, %{max_leverage: 6}).reason ==
               :leverage_limit_exceeded

      assert Perpetuals.risk_decision(
               %{@position | liquidation_px: 3_150},
               %{min_liquidation_buffer: 0.05}
             ).reason ==
               :liquidation_buffer_too_low
    end
  end

  describe "margin_summary/1" do
    test "summarizes account margin and PnL" do
      summary =
        Perpetuals.margin_summary([
          @position,
          %{
            @position
            | coin: "BTC",
              size: -1.0,
              entry_px: 100.0,
              mark_px: 90.0,
              margin_used: 200.0
          }
        ])

      assert summary.position_count == 2
      assert summary.margin_used == 1_400.0
      assert summary.unrealized_pnl == 410.0
    end
  end

  describe "execution_decision/3" do
    test "gates execution on risk checks" do
      decision =
        Perpetuals.execution_decision(
          %{coin: "ETH", side: :buy, size: 1.0, limit_px: 3_100},
          @position,
          %{max_leverage: 6}
        )

      assert decision.execute? == true
      assert decision.order.payload.coin == "ETH"

      blocked =
        Perpetuals.execution_decision(
          %{coin: "ETH", side: :buy, size: 1.0},
          %{@position | leverage: 20},
          %{max_leverage: 6}
        )

      assert blocked.execute? == false
      assert blocked.reason == :leverage_limit_exceeded
    end
  end
end
