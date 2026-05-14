defmodule Lux.Prisms.Coinbase.AdvancedTradeOpsPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Coinbase.AdvancedTradeOpsPrism

  test "returns a Coinbase Advanced Trade operation plan" do
    assert {:ok, plan} =
             AdvancedTradeOpsPrism.handler(
               %{
                 product_id: "BTC-USD",
                 order_type: "limit",
                 side: "BUY",
                 base_size: "0.01",
                 limit_price: "65000",
                 channels: ["ticker", "level2"],
                 accounts: [
                   %{currency: "BTC", available_balance: %{value: "0.1"}}
                 ],
                 prices: %{"BTC" => "65000"}
               },
               %{agent: %{name: "CoinbaseAgent"}}
             )

    assert plan.rest_api != []
    assert plan.websocket.product_ids == ["BTC-USD"]

    assert plan.order_management.create_order.order_configuration.limit_limit_gtc.base_size ==
             "0.01"

    assert plan.market_data.mid_price == nil
    assert plan.portfolio.total_value_usd == 6500.0
  end

  test "exposes prism schema" do
    view = AdvancedTradeOpsPrism.view()

    assert view.name == "Coinbase Advanced Trade Ops"
    assert Map.has_key?(view.input_schema.properties, :product_id)
    assert "order_management" in view.output_schema.required
  end
end
