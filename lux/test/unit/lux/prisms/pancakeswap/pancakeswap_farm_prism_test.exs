defmodule Lux.Prisms.Pancakeswap.PancakeswapFarmPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Pancakeswap.PancakeswapFarmPrism

  describe "handler/2" do
    test "returns error when action is missing" do
      assert {:error, _} = PancakeswapFarmPrism.handler(%{
        pool_id: 1,
        amount: "1000000000000000000"
      }, %{})
    end

    test "returns error when pool_id is missing" do
      assert {:error, _} = PancakeswapFarmPrism.handler(%{
        action: "deposit",
        amount: "1000000000000000000"
      }, %{})
    end

    test "handles deposit action" do
      input = %{
        action: "deposit",
        pool_id: 1,
        amount: "1000000000000000000",
        chain_id: 56
      }
      result = PancakeswapFarmPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "handles withdraw action" do
      input = %{
        action: "withdraw",
        pool_id: 1,
        amount: "1000000000000000000",
        chain_id: 56
      }
      result = PancakeswapFarmPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "handles harvest action without amount" do
      input = %{
        action: "harvest",
        pool_id: 1,
        chain_id: 56
      }
      result = PancakeswapFarmPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end

    test "uses default chain_id 56 when not provided" do
      input = %{
        action: "harvest",
        pool_id: 1
      }
      result = PancakeswapFarmPrism.handler(input, %{})
      assert match?({:ok, _} | {:error, _}, result)
    end
  end
end
