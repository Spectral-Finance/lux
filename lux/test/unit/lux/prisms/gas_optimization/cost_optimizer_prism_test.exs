defmodule Lux.Prisms.GasOptimization.CostOptimizerPrismTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.GasOptimization.CostOptimizerPrism

  setup do
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])

    :ok
  end

  defp mock_gas_oracle do
    Req.Test.expect(Lux.Lens, fn conn ->
      Req.Test.json(conn, %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "LastBlock" => "19000000",
          "SafeGasPrice" => "15",
          "ProposeGasPrice" => "20",
          "FastGasPrice" => "30",
          "suggestBaseFee" => "18.5",
          "gasUsedRatio" => "0.45,0.52,0.61,0.48,0.55"
        }
      })
    end)
  end

  describe "handler/2" do
    test "optimizes transactions with explicit gas price" do
      input = %{
        transactions: [
          %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "low"},
          %{type: "swap", gas_estimate: 150_000, urgency: "medium"}
        ],
        current_gas_gwei: 25.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      assert is_number(result.total_estimated_cost_eth)
      assert result.total_estimated_cost_eth > 0
      assert result.gas_price_gwei == 25.0
      assert result.transaction_count == 2
      assert is_list(result.optimizations)
      assert length(result.optimizations) > 0
      assert is_list(result.optimized_execution_plan)
      assert is_list(result.l2_alternatives)
    end

    test "auto-fetches gas price from network" do
      mock_gas_oracle()

      input = %{
        transactions: [
          %{type: "eth_transfer", gas_estimate: 21_000, urgency: "medium"}
        ]
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      assert result.gas_price_gwei > 0
      assert result.total_estimated_cost_eth > 0
    end

    test "analyzes budget correctly - within budget" do
      input = %{
        transactions: [
          %{type: "eth_transfer", gas_estimate: 21_000, urgency: "medium"}
        ],
        current_gas_gwei: 20.0,
        budget_eth: 1.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      assert result.within_budget == true
      assert result.budget_remaining_eth > 0
    end

    test "analyzes budget correctly - over budget" do
      input = %{
        transactions: [
          %{type: "swap", gas_estimate: 150_000, urgency: "high"},
          %{type: "swap", gas_estimate: 150_000, urgency: "high"},
          %{type: "contract_deploy", gas_estimate: 500_000, urgency: "medium"}
        ],
        current_gas_gwei: 100.0,
        budget_eth: 0.00001
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      # With 100 gwei and 800k gas, cost >> 0.00001 ETH
      assert result.total_estimated_cost_eth > 0.00001
    end

    test "suggests timing optimization for low-urgency transactions" do
      input = %{
        transactions: [
          %{type: "swap", gas_estimate: 150_000, urgency: "low"},
          %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "low"}
        ],
        current_gas_gwei: 30.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      strategies = Enum.map(result.optimizations, & &1.strategy)
      assert "timing_optimization" in strategies
    end

    test "suggests batching for same-type transactions" do
      input = %{
        transactions: [
          %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "medium"},
          %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "medium"},
          %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "medium"}
        ],
        current_gas_gwei: 25.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      strategies = Enum.map(result.optimizations, & &1.strategy)
      assert "transaction_batching" in strategies
    end

    test "suggests permit pattern for approve + transfer" do
      input = %{
        transactions: [
          %{type: "erc20_approve", gas_estimate: 46_000, urgency: "medium"},
          %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "medium"}
        ],
        current_gas_gwei: 20.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      strategies = Enum.map(result.optimizations, & &1.strategy)
      assert "permit_pattern" in strategies
    end

    test "always suggests EIP-1559 pricing" do
      input = %{
        transactions: [
          %{type: "eth_transfer", gas_estimate: 21_000, urgency: "medium"}
        ],
        current_gas_gwei: 20.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      strategies = Enum.map(result.optimizations, & &1.strategy)
      assert "eip1559_pricing" in strategies
    end

    test "suggests L2 migration in aggressive mode" do
      input = %{
        transactions: [
          %{type: "swap", gas_estimate: 150_000, urgency: "medium"},
          %{type: "swap", gas_estimate: 150_000, urgency: "medium"}
        ],
        current_gas_gwei: 50.0,
        optimization_level: "aggressive"
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      strategies = Enum.map(result.optimizations, & &1.strategy)
      assert "l2_migration" in strategies
    end

    test "includes L2 alternatives with cost comparison" do
      input = %{
        transactions: [
          %{type: "swap", gas_estimate: 150_000, urgency: "medium"}
        ],
        current_gas_gwei: 30.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      assert length(result.l2_alternatives) > 0

      Enum.each(result.l2_alternatives, fn alt ->
        assert Map.has_key?(alt, :network)
        assert Map.has_key?(alt, :estimated_cost_eth)
        assert Map.has_key?(alt, :savings_eth)
        assert Map.has_key?(alt, :savings_pct)
        assert alt.savings_pct > 0
      end)
    end

    test "orders execution plan by urgency" do
      input = %{
        transactions: [
          %{type: "eth_transfer", gas_estimate: 21_000, urgency: "low"},
          %{type: "swap", gas_estimate: 150_000, urgency: "critical"},
          %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "high"}
        ],
        current_gas_gwei: 20.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      urgencies = Enum.map(result.optimized_execution_plan, & &1.urgency)
      # Critical should come first
      assert List.first(urgencies) == "critical"
    end

    test "calculates potential savings" do
      input = %{
        transactions: [
          %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "low"},
          %{type: "erc20_transfer", gas_estimate: 65_000, urgency: "low"}
        ],
        current_gas_gwei: 25.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      assert result.potential_savings_eth >= 0
      assert result.potential_savings_pct >= 0
    end

    test "uses default gas estimates when not provided" do
      input = %{
        transactions: [
          %{type: "eth_transfer"},
          %{type: "swap"}
        ],
        current_gas_gwei: 20.0
      }

      assert {:ok, result} = CostOptimizerPrism.handler(input, nil)

      # Should use default gas estimates
      assert result.total_gas > 0
    end
  end

  describe "view/0" do
    test "returns prism struct" do
      prism = CostOptimizerPrism.view()

      assert prism.name == "Gas Cost Optimizer"
      assert prism.description =~ "cost optimization"
    end
  end
end
