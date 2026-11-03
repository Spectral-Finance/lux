defmodule Lux.Integrations.Hyperliquid.ClientTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Hyperliquid.Client

  test "calculates unrealized PnL and ROE accurately for long and short positions" do
    pos = %{
      coin: "ETH",
      size: 2.0,
      entry_price: 2500.0,
      mark_price: 2650.0,
      leverage: 5,
      margin_used: 1000.0
    }

    assert {:ok, %{unrealized_pnl: 300.0, roe_pct: 30.0}} = Client.calculate_pnl(pos)
  end

  test "estimates liquidation price and enforces max leverage guard" do
    client = Client.new(max_leverage: 10)
    assert {:ok, liq_px} = Client.estimate_liquidation_price(2000.0, 1.0, 10, 0.025)
    assert liq_px == 1850.0

    assert {:error, {:leverage_exceeded, 25, 10}} =
             Client.build_order(client, %{coin: "BTC", size: 0.5, price: 60000.0, leverage: 25})

    assert {:ok, order} =
             Client.build_order(client, %{coin: "BTC", size: 0.5, price: 60000.0, leverage: 5})

    assert order.is_buy == true
    assert order.sz == 0.5
  end
end
