defmodule Lux.Prisms.Pancakeswap.PancakeswapSwapPrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Pancakeswap.PancakeswapSwapPrism

  describe "handler/2" do
    test "executes swap successfully" do
      with_mock Lux.Python, [eval!: fn _, _ -> %{
        "tx_hash" => "0xabc123",
        "amount_out" => "100.0",
        "status" => "success"
      } end] do
        {:ok, result} = PancakeswapSwapPrism.run(%{
          token_in: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
          token_out: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
          amount_in: "1.0",
          slippage: 0.5
        })
        assert result.status == "success"
      end
    end

    test "handles missing private key" do
      with_mock Lux.Config, [evm_private_key: fn -> raise RuntimeError, "missing" end] do
        {:error, _error} = PancakeswapSwapPrism.run(%{
          token_in: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
          token_out: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
          amount_in: "1.0"
        })
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = PancakeswapSwapPrism.view()
      assert "token_in" in prism.input_schema.required
      assert "token_out" in prism.input_schema.required
      assert "amount_in" in prism.input_schema.required
    end
  end
end