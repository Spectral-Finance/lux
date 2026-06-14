defmodule Lux.Prisms.Hyperliquid.HyperliquidMarginPrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Hyperliquid.HyperliquidMarginPrism

  describe "handler/2" do
    test "adds margin successfully" do
      with_mock Lux.Python, [eval!: fn _, _ ->
        {:ok, %{"status" => "ok"}}
      end] do
        {:ok, result} = HyperliquidMarginPrism.run(%{coin: "ETH", amount: 100.0})
        assert result.status == "success"
        assert is_map(result.margin_result)
      end
    end

    test "removes margin successfully" do
      with_mock Lux.Python, [eval!: fn _, _ ->
        {:ok, %{"status" => "ok"}}
      end] do
        {:ok, result} = HyperliquidMarginPrism.run(%{coin: "ETH", amount: -50.0})
        assert result.status == "success"
      end
    end

    test "handles missing private key" do
      with_mock Lux.Config, [hyperliquid_account_key: fn -> raise RuntimeError, "missing" end] do
        {:error, error} = HyperliquidMarginPrism.run(%{coin: "ETH", amount: 100.0})
        assert String.contains?(error, "private key")
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = HyperliquidMarginPrism.view()
      assert prism.input_schema.required == ["coin", "amount"]
    end

    test "validates output schema" do
      prism = HyperliquidMarginPrism.view()
      assert prism.output_schema.required == ["status", "margin_result"]
    end
  end
end