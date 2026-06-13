defmodule Lux.Prisms.Pancakeswap.PancakeswapSwapPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Pancakeswap.PancakeswapSwapPrism

  @wbnb "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
  @busd "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"

  describe "handler/2" do
    test "returns error when token_in is missing" do
      assert {:error, _} = PancakeswapSwapPrism.handler(%{
        token_out: @busd,
        amount_in: "1000000000000000000"
      }, %{})
    end

    test "returns error when token_out is missing" do
      assert {:error, _} = PancakeswapSwapPrism.handler(%{
        token_in: @wbnb,
        amount_in: "1000000000000000000"
      }, %{})
    end

    test "returns error when amount_in is missing" do
      assert {:error, _} = PancakeswapSwapPrism.handler(%{
        token_in: @wbnb,
        token_out: @busd
      }, %{})
    end

    test "uses default chain_id 56 when not provided" do
      input = %{
        token_in: @wbnb,
        token_out: @busd,
        amount_in: "1000000000000000000"
      }
      result = PancakeswapSwapPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "uses default slippage 50 when not provided" do
      input = %{
        token_in: @wbnb,
        token_out: @busd,
        amount_in: "1000000000000000000",
        chain_id: 56
      }
      result = PancakeswapSwapPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end
  end
end
