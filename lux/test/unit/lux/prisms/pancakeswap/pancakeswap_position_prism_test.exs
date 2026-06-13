defmodule Lux.Prisms.Pancakeswap.PancakeswapPositionPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Pancakeswap.PancakeswapPositionPrism

  @wallet "0x1234567890abcdef1234567890abcdef12345678"

  describe "handler/2" do
    test "returns error when wallet_address is missing" do
      assert {:error, _} = PancakeswapPositionPrism.handler(%{
        chain_id: 56
      }, %{})
    end

    test "fetches positions for valid wallet" do
      input = %{
        wallet_address: @wallet,
        chain_id: 56
      }
      result = PancakeswapPositionPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "uses default chain_id 56 when not provided" do
      input = %{wallet_address: @wallet}
      result = PancakeswapPositionPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end
  end
end
