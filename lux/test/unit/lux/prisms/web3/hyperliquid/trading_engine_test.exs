defmodule Lux.Prisms.Web3.Hyperliquid.TradingEngineTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.Hyperliquid.TradingEngine

  setup do
    name = :"hl_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = TradingEngine.start_link(name: name, max_leverage: 50)
    %{pid: pid}
  end

  # --- Order Placement ---

  test "place valid order", %{pid: pid} do
    {:ok, order} = TradingEngine.place_order(pid, %{symbol: "BTC-PERP", side: :long, price: 65000, size: 1, leverage: 10})
    assert order.symbol == "BTC-PERP"
    assert order.side == :long
    assert order.status == :open
    assert order.leverage == 10
    assert is_binary(order.id)
  end

  test "place market order", %{pid: pid} do
    {:ok, order} = TradingEngine.place_order(pid, %{symbol: "ETH-PERP", side: :short, type: :market, size: 5})
    assert order.type == :market
  end

  test "reject excessive leverage", %{pid: pid} do
    assert {:error, :leverage_exceeded} = TradingEngine.place_order(pid, %{symbol: "BTC", side: :long, leverage: 100})
  end

  test "reject zero leverage", %{pid: pid} do
    assert {:error, :invalid_leverage} = TradingEngine.place_order(pid, %{symbol: "BTC", side: :long, leverage: 0})
  end

  test "reject invalid side", %{pid: pid} do
    assert {:error, :invalid_side} = TradingEngine.place_order(pid, %{symbol: "BTC", side: :up})
  end

  test "reject missing symbol", %{pid: pid} do
    assert {:error, :missing_symbol} = TradingEngine.place_order(pid, %{side: :long})
  end

  test "reject invalid order type", %{pid: pid} do
    assert {:error, :invalid_order_type} = TradingEngine.place_order(pid, %{symbol: "BTC", side: :long, type: :stop})
  end

  test "reject negative size", %{pid: pid} do
    assert {:error, :invalid_size} = TradingEngine.place_order(pid, %{symbol: "BTC", side: :long, size: -1})
  end

  # --- Order Cancellation ---

  test "cancel order", %{pid: pid} do
    {:ok, order} = TradingEngine.place_order(pid, %{symbol: "ETH", side: :short, price: 3000, size: 5})
    {:ok, cancelled} = TradingEngine.cancel_order(pid, order.id)
    assert cancelled.status == :cancelled
  end

  test "cancel already cancelled", %{pid: pid} do
    {:ok, order} = TradingEngine.place_order(pid, %{symbol: "ETH", side: :long})
    {:ok, _} = TradingEngine.cancel_order(pid, order.id)
    assert {:error, :already_cancelled} = TradingEngine.cancel_order(pid, order.id)
  end

  test "cancel nonexistent", %{pid: pid} do
    assert {:error, :not_found} = TradingEngine.cancel_order(pid, "nope")
  end

  # --- Order Listing ---

  test "list only open orders", %{pid: pid} do
    {:ok, _} = TradingEngine.place_order(pid, %{symbol: "BTC", side: :long})
    {:ok, o2} = TradingEngine.place_order(pid, %{symbol: "ETH", side: :short})
    TradingEngine.cancel_order(pid, o2.id)
    {:ok, open} = TradingEngine.list_orders(pid)
    assert length(open) == 1
  end

  # --- Leverage ---

  test "set leverage", %{pid: pid} do
    {:ok, pos} = TradingEngine.set_leverage(pid, "BTC-PERP", 20)
    assert pos.leverage == 20
  end

  test "set leverage exceeds max", %{pid: pid} do
    assert {:error, :leverage_exceeded} = TradingEngine.set_leverage(pid, "BTC", 100)
  end

  test "set leverage below minimum", %{pid: pid} do
    assert {:error, :invalid_leverage} = TradingEngine.set_leverage(pid, "BTC", 0)
  end

  # --- Positions ---

  test "close position with pnl tracking", %{pid: pid} do
    TradingEngine.set_leverage(pid, "BTC", 10)
    {:ok, result} = TradingEngine.close_position(pid, "BTC")
    assert result.pnl.symbol == "BTC"
    # Position should be removed
    assert {:error, :no_position} = TradingEngine.get_position(pid, "BTC")
  end

  test "close nonexistent position", %{pid: pid} do
    assert {:error, :no_position} = TradingEngine.close_position(pid, "DOGE")
  end

  test "list positions", %{pid: pid} do
    TradingEngine.set_leverage(pid, "BTC", 10)
    TradingEngine.set_leverage(pid, "ETH", 5)
    {:ok, positions} = TradingEngine.list_positions(pid)
    assert length(positions) == 2
  end

  test "list positions empty", %{pid: pid} do
    {:ok, positions} = TradingEngine.list_positions(pid)
    assert positions == []
  end

  # --- Risk ---

  test "risk check low leverage", %{pid: pid} do
    TradingEngine.set_leverage(pid, "BTC", 5)
    {:ok, risk} = TradingEngine.risk_check(pid)
    assert risk.risk_level == :low
    assert risk.total_positions == 1
    assert risk.within_limits
  end

  test "risk check high leverage", %{pid: pid} do
    TradingEngine.set_leverage(pid, "BTC", 25)
    {:ok, risk} = TradingEngine.risk_check(pid)
    assert risk.risk_level == :high
  end

  test "risk check empty", %{pid: pid} do
    {:ok, risk} = TradingEngine.risk_check(pid)
    assert risk.total_positions == 0
    assert risk.risk_level == :low
  end

  # --- PnL ---

  test "pnl summary empty", %{pid: pid} do
    {:ok, pnl} = TradingEngine.pnl_summary(pid)
    assert pnl.total_pnl == 0
    assert pnl.trades == 0
    assert pnl.win_rate == 0.0
  end

  test "pnl after closing positions", %{pid: pid} do
    TradingEngine.set_leverage(pid, "BTC", 10)
    TradingEngine.close_position(pid, "BTC")
    TradingEngine.set_leverage(pid, "ETH", 5)
    TradingEngine.close_position(pid, "ETH")
    {:ok, pnl} = TradingEngine.pnl_summary(pid)
    assert pnl.trades == 2
  end
end
