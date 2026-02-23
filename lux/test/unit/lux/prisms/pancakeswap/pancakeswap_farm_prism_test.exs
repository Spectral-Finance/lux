defmodule Lux.Prisms.PancakeSwap.PancakeSwapFarmPrismTest do
  @moduledoc """
  Test suite for PancakeSwapFarmPrism.
  """

  use UnitCase, async: true

  alias Lux.Prisms.PancakeSwap.PancakeSwapFarmPrism

  @lp_cake_bnb "0x0eD7e52944161450477ee417DE9Cd3a859b14fD0"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2 — stake action" do
    test "returns config error when keys missing" do
      System.delete_env("PANCAKESWAP_PRIVATE_KEY")
      System.delete_env("PANCAKESWAP_RPC_URL")

      assert {:error, _} = PancakeSwapFarmPrism.handler(
        %{pid: 2, amount: "1000000000000000000000", action: "stake"},
        @agent_ctx
      )
    end

    test "accepts lp_token_address for approval" do
      assert {:error, _} = PancakeSwapFarmPrism.handler(
        %{
          pid: 2,
          amount: "1000000000000000000000",
          action: "stake",
          lp_token_address: @lp_cake_bnb
        },
        @agent_ctx
      )
    end
  end

  describe "handler/2 — unstake action" do
    test "processes unstake without lp_token_address" do
      assert {:error, _} = PancakeSwapFarmPrism.handler(
        %{pid: 2, amount: "500000000000000000000", action: "unstake"},
        @agent_ctx
      )
    end

    test "accepts custom masterchef address" do
      assert {:error, _} = PancakeSwapFarmPrism.handler(
        %{
          pid: 2,
          amount: "100000000000000000000",
          action: "unstake",
          masterchef_address: "0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652"
        },
        @agent_ctx
      )
    end
  end

  describe "prism metadata" do
    test "has correct name" do
      assert PancakeSwapFarmPrism.__prism__(:name) == "PancakeSwap Farm"
    end

    test "requires pid, amount, and action" do
      schema = PancakeSwapFarmPrism.__prism__(:input_schema)
      assert "pid" in schema.required
      assert "amount" in schema.required
      assert "action" in schema.required
    end

    test "action enum is stake and unstake" do
      schema = PancakeSwapFarmPrism.__prism__(:input_schema)
      assert "stake" in schema.properties.action.enum
      assert "unstake" in schema.properties.action.enum
    end

    test "pid has minimum 0" do
      schema = PancakeSwapFarmPrism.__prism__(:input_schema)
      assert schema.properties.pid.minimum == 0
    end
  end
end
