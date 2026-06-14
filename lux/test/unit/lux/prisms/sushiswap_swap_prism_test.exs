defmodule Lux.Prisms.Sushiswap.SushiswapSwapPrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Sushiswap.SushiswapSwapPrism

  describe "handler/2" do
    test "executes swap successfully" do
      with_mock Lux.Python, [eval!: fn _, _ -> %{
        "tx_hash" => "0xabc123",
        "amount_out" => "100.0",
        "status" => "success"
      } end] do
        {:ok, result} = SushiswapSwapPrism.run(%{
          token_in: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
          token_out: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
          amount_in: "1.0",
          chain_id: 1
        })
        assert result.status == "success"
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SushiswapSwapPrism.view()
      assert "token_in" in prism.input_schema.required
      assert "token_out" in prism.input_schema.required
      assert "amount_in" in prism.input_schema.required
    end
  end
end