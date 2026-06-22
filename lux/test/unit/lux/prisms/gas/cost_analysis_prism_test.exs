defmodule Lux.Prisms.Gas.CostAnalysisPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Gas.CostAnalysisPrism

  describe "handler/2 - basic functionality" do
    test "returns comprehensive cost analysis" do
      result = CostAnalysisPrism.handler(%{
        transaction_type: "eth_transfer",
        estimated_gas: 21000,
        chain_id: 1
      })

      assert {:ok, report} = result
      assert is_number(report.current_gas_price_gwei)
      assert is_integer(report.current_cost_wei)
      assert report.current_cost_wei > 0
      assert is_number(report.current_cost_eth)
      assert report.current_cost_eth > 0
      assert is_number(report.batch_cost_eth)
      assert is_number(report.optimal_gas_price_gwei)
      assert is_number(report.optimal_cost_eth)
      assert report.optimal_cost_eth <= report.current_cost_eth
      assert is_number(report.cost_savings_percent)
      assert report.cost_savings_percent >= 0
      assert report.cost_trend in ["increasing", "decreasing", "stable"]
      assert is_binary(report.recommended_time)
      assert is_number(report.historical_avg_24h_gwei)
      assert is_number(report.historical_min_24h_gwei)
      assert is_number(report.historical_max_24h_gwei)
      assert is_number(report.percentile_rank)
      assert report.percentile_rank >= 0 and report.percentile_rank <= 100
      assert is_number(report.daily_budget_estimate)
      assert report.transaction_type == "eth_transfer"
      assert report.estimated_gas == 21000
      assert report.chain_id == 1
    end

    test "handles ERC20 transfer type" do
      result = CostAnalysisPrism.handler(%{
        transaction_type: "erc20_transfer",
        chain_id: 1
      })

      assert {:ok, report} = result
      assert report.estimated_gas == 65000
      assert report.transaction_type == "erc20_transfer"
    end

    test "handles custom gas estimate override" do
      result = CostAnalysisPrism.handler(%{
        transaction_type: "custom",
        estimated_gas: 100_000,
        chain_id: 1
      })

      assert {:ok, report} = result
      assert report.estimated_gas == 100_000
    end

    test "calculates batch cost correctly" do
      result = CostAnalysisPrism.handler(%{
        transaction_type: "eth_transfer",
        estimated_gas: 21000,
        batch_size: 10,
        chain_id: 1
      })

      assert {:ok, report} = result
      assert report.batch_cost_eth >= report.current_cost_eth
    end

    test "handles multiple transaction types" do
      types = ~w(eth_transfer erc20_approve erc20_transfer erc721_mint uniswap_swap aave_deposit)a

      for tx_type <- types do
        result = CostAnalysisPrism.handler(%{
          transaction_type: Atom.to_string(tx_type),
          chain_id: 1
        })

        assert {:ok, report} = result
        assert report.transaction_type == Atom.to_string(tx_type)
        assert report.estimated_gas > 0
      end
    end

    test "optimization saves gas cost" do
      result = CostAnalysisPrism.handler(%{
        transaction_type: "eth_transfer",
        chain_id: 1
      })

      assert {:ok, report} = result
      assert report.optimal_cost_eth <= report.current_cost_eth
      assert report.cost_savings_percent >= 0
    end

    test "handles missing parameters with defaults" do
      result = CostAnalysisPrism.handler(%{})

      assert {:ok, report} = result
      assert report.transaction_type == "eth_transfer"
      assert report.estimated_gas == 21000
    end
  end
