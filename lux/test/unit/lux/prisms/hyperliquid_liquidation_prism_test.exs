defmodule Lux.Prisms.Hyperliquid.HyperliquidLiquidationPrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Hyperliquid.HyperliquidLiquidationPrism

  @test_address "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

  describe "handler/2" do
    test "returns at risk and safe positions" do
      with_mock Lux.Python, [eval!: fn _, _ ->
        {:ok, %{
          "at_risk_positions" => [%{"coin" => "ETH", "distance_pct" => "5.0"}],
          "safe_positions" => [%{"coin" => "BTC", "distance_pct" => "25.0"}],
          "account_value" => "10000.0",
          "margin_usage" => "1000.0"
        }}
      end] do
        {:ok, result} = HyperliquidLiquidationPrism.run(%{address: @test_address})
        assert result.status == "success"
        assert is_list(result.at_risk_positions)
        assert is_list(result.safe_positions)
      end
    end

    test "uses custom risk threshold" do
      with_mock Lux.Python, [eval!: fn _, _ ->
        {:ok, %{
          "at_risk_positions" => [],
          "safe_positions" => [],
          "account_value" => "10000.0",
          "margin_usage" => "0"
        }}
      end] do
        {:ok, result} = HyperliquidLiquidationPrism.run(%{
          address: @test_address,
          risk_threshold: 0.05
        })
        assert result.status == "success"
      end
    end

    test "handles missing private key" do
      with_mock Lux.Config, [hyperliquid_account_key: fn -> raise RuntimeError, "missing" end] do
        {:error, error} = HyperliquidLiquidationPrism.run(%{address: @test_address})
        assert String.contains?(error, "private key")
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = HyperliquidLiquidationPrism.view()
      assert prism.input_schema.required == ["address"]
    end

    test "validates output schema" do
      prism = HyperliquidLiquidationPrism.view()
      assert "at_risk_positions" in prism.output_schema.required
      assert "safe_positions" in prism.output_schema.required
    end
  end
end