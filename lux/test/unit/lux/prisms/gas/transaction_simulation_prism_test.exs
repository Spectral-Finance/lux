defmodule Lux.Prisms.Gas.TransactionSimulationPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Gas.TransactionSimulationPrism

  describe "handler/2 - basic functionality" do
    test "requires recipient address" do
      result = TransactionSimulationPrism.handler(%{
        value: "1000000000000000000"
      })

      assert {:error, reason} = result
      assert reason =~ "Recipient address"
    end

    test "simulates simple ETH transfer" do
      result = TransactionSimulationPrism.handler(%{
        to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
        value: "1000000000000000000",
        network: "mainnet"
      })

      assert {:ok, sim} = result
      assert sim.simulated == true
      assert is_integer(sim.estimated_gas)
      assert sim.estimated_gas > 0
      assert is_integer(sim.estimated_cost_wei)
      assert sim.estimated_cost_wei >= 0
      assert is_number(sim.estimated_cost_eth)
      assert sim.success in [true, false, nil]
      assert sim.network == "mainnet"
    end

    test "simulates with custom gas price" do
      result = TransactionSimulationPrism.handler(%{
        to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
        value: "1000000000000000000",
        gas_price_gwei: 40,
        network: "mainnet"
      })

      assert {:ok, sim} = result
      assert sim.estimated_cost_wei > 0
    end

    test "uses default gas estimate for simple transfers" do
      result = TransactionSimulationPrism.handler(%{
        to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
        value: "1000000000000000000"
      })

      assert {:ok, sim} = result
      # Simple ETH transfer should estimate around 21000 gas
      assert sim.estimated_gas >= 21000
    end

    test "handles contract interaction simulation" do
      result = TransactionSimulationPrism.handler(%{
        to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
        value: "0",
        data: "0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f2bd180000000000000000000000000000000000000000000000000de0b6b3a7640000",
        gas_price_gwei: 30
      })

      assert {:ok, sim} = result
      assert sim.estimated_gas >= 21000
    end

    test "simulates on different networks" do
      for network <- ["mainnet", "goerli", "sepolia"] do
        result = TransactionSimulationPrism.handler(%{
          to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
          network: network
        })

        assert {:ok, sim} = result
        assert sim.network == network
      end
    end
  end
