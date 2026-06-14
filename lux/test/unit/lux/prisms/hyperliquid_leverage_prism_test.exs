defmodule Lux.Prisms.Hyperliquid.HyperliquidLeveragePrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Hyperliquid.HyperliquidLeveragePrism

  describe "handler/2" do
    test "sets leverage successfully" do
      with_mock Lux.Python, [run_python: fn _, _ ->
        {:ok, %{"status" => "ok"}}
      end] do
        {:ok, result} = HyperliquidLeveragePrism.run(%{coin: "ETH", leverage: 5, is_cross: true})
        assert result.status == "success"
      end
    end

    test "handles missing private key" do
      with_mock Lux.Config, [hyperliquid_account_key: fn -> raise RuntimeError, "missing" end] do
        {:error, error} = HyperliquidLeveragePrism.run(%{coin: "ETH", leverage: 5})
        assert String.contains?(error, "private key")
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = HyperliquidLeveragePrism.view()
      assert prism.input_schema.required == ["coin", "leverage"]
    end

    test "validates output schema" do
      prism = HyperliquidLeveragePrism.view()
      assert prism.output_schema.required == ["status", "leverage_result"]
    end
  end
end