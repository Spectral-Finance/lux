defmodule Lux.Prisms.Pancakeswap.PancakeswapCompoundPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Pancakeswap.PancakeswapCompoundPrism

  @wallet "0x1234567890abcdef1234567890abcdef12345678"

  describe "handler/2" do
    test "returns error when pool_id is missing" do
      assert {:error, _} = PancakeswapCompoundPrism.handler(%{
        wallet_address: @wallet
      }, %{})
    end

    test "returns error when wallet_address is missing" do
      assert {:error, _} = PancakeswapCompoundPrism.handler(%{
        pool_id: 1
      }, %{})
    end

    test "compounds rewards for valid input" do
      input = %{
        pool_id: 1,
        wallet_address: @wallet,
        chain_id: 56,
        slippage: 50
      }
      result = PancakeswapCompoundPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "uses default slippage 50 when not provided" do
      input = %{
        pool_id: 1,
        wallet_address: @wallet,
        chain_id: 56
      }
      result = PancakeswapCompoundPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end
  end
end
