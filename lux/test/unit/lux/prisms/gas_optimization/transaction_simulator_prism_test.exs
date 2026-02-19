defmodule Lux.Prisms.GasOptimization.TransactionSimulatorPrismTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.GasOptimization.TransactionSimulatorPrism

  describe "handler/2" do
    test "simulates a basic ETH transfer" do
      input = %{
        transactions: [
          %{
            from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18",
            value: "1000000000000000000",
            data: "0x"
          }
        ],
        gas_price_gwei: 20.0
      }

      assert {:ok, result} = TransactionSimulatorPrism.handler(input, nil)

      assert result.all_successful == true
      assert result.total_gas > 0
      assert result.total_cost_eth > 0
      assert length(result.simulations) == 1

      [sim] = result.simulations
      assert sim.status == "success"
      assert sim.tx_type == "eth_transfer"
      assert sim.gas_used == 21_000
      assert sim.cost_eth > 0
    end

    test "simulates an ERC20 transfer" do
      input = %{
        transactions: [
          %{
            from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            to: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
            data: "0xa9059cbb0000000000000000000000001234567890123456789012345678901234567890"
          }
        ],
        gas_price_gwei: 25.0
      }

      assert {:ok, result} = TransactionSimulatorPrism.handler(input, nil)

      [sim] = result.simulations
      assert sim.tx_type == "erc20_transfer"
      assert sim.gas_used > 21_000
    end

    test "simulates a DEX swap" do
      input = %{
        transactions: [
          %{
            from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
            data: "0x38ed17390000000000000000000000000000000000000000000000000de0b6b3a7640000"
          }
        ],
        gas_price_gwei: 30.0
      }

      assert {:ok, result} = TransactionSimulatorPrism.handler(input, nil)

      [sim] = result.simulations
      assert sim.tx_type == "dex_swap"
      assert sim.gas_used > 100_000
    end

    test "simulates multiple transactions" do
      input = %{
        transactions: [
          %{
            from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18",
            value: "1000000000000000000"
          },
          %{
            from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            to: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
            data: "0xa9059cbb"
          }
        ],
        gas_price_gwei: 20.0
      }

      assert {:ok, result} = TransactionSimulatorPrism.handler(input, nil)

      assert length(result.simulations) == 2
      assert result.total_gas == Enum.sum(Enum.map(result.simulations, & &1.gas_used))
    end

    test "detects insufficient gas limit" do
      input = %{
        transactions: [
          %{
            from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            to: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
            data: "0xa9059cbb0000000000",
            gas_limit: 10_000  # Way too low
          }
        ],
        gas_price_gwei: 20.0
      }

      assert {:ok, result} = TransactionSimulatorPrism.handler(input, nil)

      [sim] = result.simulations
      assert sim.status == "failed"
      assert length(sim.warnings) > 0
      assert result.all_successful == false
    end

    test "includes gas breakdown when trace requested" do
      input = %{
        transactions: [
          %{
            from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            to: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
            data: "0xa9059cbb"
          }
        ],
        gas_price_gwei: 20.0,
        include_trace: true
      }

      assert {:ok, result} = TransactionSimulatorPrism.handler(input, nil)

      [sim] = result.simulations
      assert Map.has_key?(sim, :gas_breakdown)
      assert is_map(sim.gas_breakdown)
    end

    test "returns error for empty transactions" do
      assert {:error, "No transactions provided for simulation"} =
               TransactionSimulatorPrism.handler(%{transactions: []}, nil)
    end

    test "uses default gas price when not specified" do
      input = %{
        transactions: [
          %{
            from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
            to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18"
          }
        ]
      }

      assert {:ok, result} = TransactionSimulatorPrism.handler(input, nil)

      assert result.gas_price_gwei == 20.0
    end
  end

  describe "estimate_gas/3" do
    test "estimates gas for ETH transfer" do
      {gas, type} = TransactionSimulatorPrism.estimate_gas("0xabc", "0x", "1000")
      assert gas == 21_000
      assert type == "eth_transfer"
    end

    test "estimates gas for ERC20 transfer" do
      {gas, type} = TransactionSimulatorPrism.estimate_gas("0xabc", "0xa9059cbb", "0")
      assert gas > 21_000
      assert type == "erc20_transfer"
    end

    test "estimates gas for contract creation" do
      {gas, type} = TransactionSimulatorPrism.estimate_gas("", "0xdeadbeef", "0")
      assert gas > 32_000
      assert type == "contract_creation"
    end

    test "estimates gas for swap" do
      {gas, type} = TransactionSimulatorPrism.estimate_gas("0xabc", "0x38ed1739", "0")
      assert gas > 100_000
      assert type == "dex_swap"
    end

    test "estimates gas for generic contract call" do
      {gas, type} = TransactionSimulatorPrism.estimate_gas("0xabc", "0xdeadbeef", "0")
      assert gas > 21_000
      assert type == "contract_call"
    end
  end

  describe "classify_transaction/3" do
    test "classifies ETH transfer" do
      assert TransactionSimulatorPrism.classify_transaction("0xabc", "0x", "1000") == "eth_transfer"
      assert TransactionSimulatorPrism.classify_transaction("0xabc", "", "1000") == "eth_transfer"
      assert TransactionSimulatorPrism.classify_transaction("0xabc", nil, "1000") == "eth_transfer"
    end

    test "classifies contract creation" do
      assert TransactionSimulatorPrism.classify_transaction("", "0xdeadbeef", "0") == "contract_creation"
      assert TransactionSimulatorPrism.classify_transaction(nil, "0xdeadbeef", "0") == "contract_creation"
    end

    test "classifies ERC20 transfer" do
      assert TransactionSimulatorPrism.classify_transaction("0xabc", "0xa9059cbb", "0") == "erc20_transfer"
    end

    test "classifies ERC20 approve" do
      assert TransactionSimulatorPrism.classify_transaction("0xabc", "0x095ea7b3", "0") == "erc20_approve"
    end

    test "classifies DEX swap" do
      assert TransactionSimulatorPrism.classify_transaction("0xabc", "0x38ed1739abcd", "0") == "dex_swap"
    end
  end

  describe "simulate_transaction/3" do
    test "returns correct structure" do
      tx = %{
        from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18",
        value: "0",
        data: "0x"
      }

      result = TransactionSimulatorPrism.simulate_transaction(tx, 20.0, false)

      assert Map.has_key?(result, :status)
      assert Map.has_key?(result, :gas_used)
      assert Map.has_key?(result, :gas_limit)
      assert Map.has_key?(result, :gas_limit_recommended)
      assert Map.has_key?(result, :cost_eth)
      assert Map.has_key?(result, :warnings)
    end

    test "validates addresses" do
      tx = %{
        from: "invalid",
        to: "also_invalid",
        value: "0",
        data: "0x"
      }

      result = TransactionSimulatorPrism.simulate_transaction(tx, 20.0, false)

      assert length(result.warnings) > 0
    end

    test "recommends appropriate gas limit" do
      tx = %{
        from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18",
        value: "0",
        data: "0x"
      }

      result = TransactionSimulatorPrism.simulate_transaction(tx, 20.0, false)

      assert result.gas_limit_recommended > result.gas_used
    end
  end

  describe "view/0" do
    test "returns prism struct" do
      prism = TransactionSimulatorPrism.view()

      assert prism.name == "Transaction Simulator"
      assert prism.description =~ "Simulates"
    end
  end
end
