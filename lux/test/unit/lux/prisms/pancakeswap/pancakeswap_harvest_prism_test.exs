defmodule Lux.Prisms.PancakeSwap.PancakeSwapHarvestPrismTest do
  @moduledoc """
  Test suite for PancakeSwapHarvestPrism.
  """

  use UnitCase, async: true

  alias Lux.Prisms.PancakeSwap.PancakeSwapHarvestPrism

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "returns config error when keys missing" do
      System.delete_env("PANCAKESWAP_PRIVATE_KEY")
      System.delete_env("PANCAKESWAP_RPC_URL")

      assert {:error, _} = PancakeSwapHarvestPrism.handler(%{pid: 2}, @agent_ctx)
    end

    test "accepts auto_compound flag" do
      assert {:error, _} = PancakeSwapHarvestPrism.handler(
        %{pid: 2, auto_compound: true},
        @agent_ctx
      )
    end

    test "accepts auto_compound false (simple harvest)" do
      assert {:error, _} = PancakeSwapHarvestPrism.handler(
        %{pid: 2, auto_compound: false},
        @agent_ctx
      )
    end

    test "accepts CAKE staking pool (pid 0)" do
      assert {:error, _} = PancakeSwapHarvestPrism.handler(%{pid: 0}, @agent_ctx)
    end

    test "accepts custom masterchef address" do
      assert {:error, _} = PancakeSwapHarvestPrism.handler(
        %{
          pid: 2,
          masterchef_address: "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652"
        },
        @agent_ctx
      )
    end
  end

  describe "prism metadata" do
    test "has correct name" do
      assert PancakeSwapHarvestPrism.__prism__(:name) == "PancakeSwap Harvest"
    end

    test "requires only pid" do
      schema = PancakeSwapHarvestPrism.__prism__(:input_schema)
      assert schema.required == ["pid"]
    end

    test "output includes cake_harvested and auto_compounded" do
      schema = PancakeSwapHarvestPrism.__prism__(:output_schema)
      assert Map.has_key?(schema.properties, :cake_harvested)
      assert Map.has_key?(schema.properties, :auto_compounded)
      assert Map.has_key?(schema.properties, :tx_hash)
      assert Map.has_key?(schema.properties, :status)
    end
  end
end
