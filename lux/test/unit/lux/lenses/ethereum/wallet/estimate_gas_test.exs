defmodule Lux.Lenses.Ethereum.Wallet.EstimateGasTest do
  @moduledoc """
  Test suite for the EstimateGas lens.
  Verifies gas limit and fee estimation for Ethereum transactions.
  """

  use UnitCase, async: true

  alias Lux.Lenses.Ethereum.Wallet.EstimateGas

  @agent_ctx %{agent: %{name: "TestAgent"}}
  @test_from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @test_to "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

  describe "focus/2" do
    test "estimates gas for a simple ETH transfer" do
      assert {:ok, result} = EstimateGas.focus(%{
        from: @test_from,
        to: @test_to,
        value_wei: "1000000000000000",
        network: "test"
      }, @agent_ctx)

      # Simple ETH transfer is always 21,000 gas
      assert result.gas_limit == 21_000
      assert is_binary(result.estimated_cost_eth)
      assert is_binary(result.gas_price_gwei)
      assert result.network == "test"
    end

    test "returns all required fee fields" do
      assert {:ok, result} = EstimateGas.focus(%{
        from: @test_from,
        to: @test_to,
        network: "test"
      }, @agent_ctx)

      assert Map.has_key?(result, :gas_limit)
      assert Map.has_key?(result, :gas_price_gwei)
      assert Map.has_key?(result, :estimated_cost_eth)
      assert Map.has_key?(result, :network)
      assert Map.has_key?(result, :max_fee_per_gas_gwei)
      assert Map.has_key?(result, :priority_fee_gwei)
    end

    test "gas limit is positive integer" do
      assert {:ok, result} = EstimateGas.focus(%{
        from: @test_from,
        to: @test_to,
        network: "test"
      }, @agent_ctx)

      assert is_integer(result.gas_limit)
      assert result.gas_limit > 0
    end

    test "estimated cost is a non-negative decimal string" do
      assert {:ok, result} = EstimateGas.focus(%{
        from: @test_from,
        to: @test_to,
        network: "test"
      }, @agent_ctx)

      {cost, _} = Float.parse(result.estimated_cost_eth)
      assert cost >= 0
    end
  end
end
