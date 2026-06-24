defmodule Lux.Lenses.Hyperliquid.Trading.CreateOrderTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Hyperliquid.Trading.CreateOrder

  describe "focus/2" do
    test "delegates to HyperliquidExecuteOrderPrism" do
      assert {:error, "Hyperliquid account private key is not configured"} =
        CreateOrder.focus(%{coin: "ETH", is_buy: true, sz: 0.1, limit_px: 2800.0, order_type: %{limit: %{tif: "Gtc"}}})
    end
  end
end
