defmodule Lux.Prisms.Sushiswap.SushiswapLiquidityPrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Sushiswap.SushiswapLiquidityPrism

  describe "handler/2" do
    test "adds liquidity successfully" do
      with_mock Lux.Python, [eval!: fn _, _ -> %{
        "tx_hash" => "0xabc123",
        "status" => "success",
        "lp_tokens" => "10.5"
      } end] do
        {:ok, result} = SushiswapLiquidityPrism.run(%{
          token_a: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
          token_b: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
          amount_a: "100.0",
          amount_b: "100.0",
          action: "add"
        })
        assert result.status == "success"
      end
    end

    test "removes liquidity successfully" do
      with_mock Lux.Python, [eval!: fn _, _ -> %{
        "tx_hash" => "0xdef456",
        "status" => "success",
        "amount_a" => "95.0",
        "amount_b" => "95.0"
      } end] do
        {:ok, result} = SushiswapLiquidityPrism.run(%{
          token_a: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
          token_b: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
          amount_a: "0",
          amount_b: "0",
          action: "remove"
        })
        assert result.status == "success"
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SushiswapLiquidityPrism.view()
      assert "token_a" in prism.input_schema.required
      assert "token_b" in prism.input_schema.required
    end
  end
end