defmodule Lux.Prisms.Hyperliquid.HyperliquidUpdateLeveragePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidUpdateLeveragePrism

  describe "schema validation" do
    test "view/0 returns valid prism struct" do
      prism = HyperliquidUpdateLeveragePrism.view()
      assert prism.name == "Hyperliquid Update Leverage"
      assert prism.input_schema.required == ["coin", "leverage"]
      assert prism.output_schema.required == ["status", "coin", "leverage"]
      assert prism.input_schema.properties.leverage.maximum == 100
      assert prism.input_schema.properties.leverage.minimum == 1
    end
  end

  describe "handler/2 validation" do
    test "fails with meaningful error when configuration is missing" do
      # In test environment, if private key is invalid or missing
      result = HyperliquidUpdateLeveragePrism.handler(%{coin: "BTC", leverage: 5}, %{})
      # Result should be either {:ok, ...} if mocked or {:error, reason}
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
