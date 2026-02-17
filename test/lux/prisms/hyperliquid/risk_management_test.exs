defmodule Lux.Prisms.Hyperliquid.RiskManagementTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism

  test "risk management integration for limit order" do
    result = HyperliquidExecuteOrderPrism.run(%{
      coin: "ETH",
      is_buy: true,
      sz: 0.0051,
      limit_px: 2800.0,
      order_type: %{limit: %{tif: "Gtc"}},
      reduce_only: false,
      vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
    })

    assert {:ok, %{"status" => "success", "order_result" => _}} = result
  end

  test "risk management integration for trigger order (Stop Loss)" do
    result = HyperliquidExecuteOrderPrism.run(%{
      coin: "ETH",
      is_buy: false,
      sz: 0.1,
      limit_px: 2800.0,
      order_type: %{
        trigger: %{
          triggerPx: 2900.0,
          isMarket: true,
          tpsl: "sl"
        }
      },
      reduce_only: true
    })

    assert {:ok, %{"status" => "success", "order_result" => _}} = result
  end
end