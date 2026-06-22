defmodule Lux.Prisms.Gas.GasTokenIntegrationPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Gas.GasTokenIntegrationPrism

  describe "handler/2 - basic functionality" do
    test "returns gas token optimization analysis" do
      result = GasTokenIntegrationPrism.handler(%{
        estimated_gas: 65000,
        gas_price_gwei: 30
      })

      assert {:ok, analysis} = result
      assert analysis.optimal_token in ["BAT", "GAS", "KNC", "none"]
      assert is_binary(analysis.token_contract)
      assert is_integer(analysis.potential_savings_wei)
      assert analysis.potential_savings_wei >= 0
      assert is_number(analysis.potential_savings_eth)
      assert is_boolean(analysis.swap_needed)
      assert is_binary(analysis.swap_router)
      assert is_integer(analysis.net_savings_after_swap)
      assert analysis.net_savings_after_swap >= 0
      assert is_binary(analysis.recommendation)
    end

    test "calculates savings based on gas estimate" do
      result = GasTokenIntegrationPrism.handler(%{
        estimated_gas: 100_000,
        gas_price_gwei: 50
      })

      assert {:ok, analysis} = result
      # Higher gas * higher price = more savings
      assert analysis.potential_savings_wei > 0
    end

    test "handles default gas estimate" do
      result = GasTokenIntegrationPrism.handler(%{
        gas_price_gwei: 30
      })

      assert {:ok, analysis} = result
      assert analysis.potential_savings_wei > 0
    end

    test "net savings accounts for swap cost" do
      result = GasTokenIntegrationPrism.handler(%{
        estimated_gas: 300_000,
        gas_price_gwei: 100
      })

      assert {:ok, analysis} = result
      # Net savings should be less than or equal to gross savings
      assert analysis.net_savings_after_swap <= analysis.potential_savings_wei
    end

    test "recommends BAT as default token" do
      result = GasTokenIntegrationPrism.handler(%{})

      assert {:ok, analysis} = result
      assert analysis.optimal_token == "BAT"
    end
  end
