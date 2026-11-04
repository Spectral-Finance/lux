defmodule Lux.Prisms.PancakeSwap.ApyOptimizerPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.PancakeSwap.ApyOptimizerPrism

  @ctx %{name: "TestAgent"}

  describe "apy/2" do
    test "equals the APR when compounded once" do
      assert ApyOptimizerPrism.apy(0.5, 1) == 0.5
    end

    test "grows with the compounding frequency" do
      assert_in_delta ApyOptimizerPrism.apy(1.0, 2), 1.25, 1.0e-12
      assert ApyOptimizerPrism.apy(0.5, 365) > ApyOptimizerPrism.apy(0.5, 12)
      assert ApyOptimizerPrism.apy(0.5, 12) > ApyOptimizerPrism.apy(0.5, 1)
      # approaches e^r - 1 for continuous compounding
      assert_in_delta ApyOptimizerPrism.apy(0.5, 1_000_000), :math.exp(0.5) - 1, 1.0e-6
    end

    test "is zero for a zero APR" do
      assert ApyOptimizerPrism.apy(0, 12) == 0.0
    end
  end

  describe "handler/2" do
    test "ranks pools by net APY and reports the best pool" do
      assert {:ok, result} =
               ApyOptimizerPrism.handler(
                 %{
                   pools: [
                     %{id: "usdt-busd", apr: 0.1, tvl_usd: 5_000_000},
                     %{id: "cake-bnb", apr: 0.4},
                     %{id: "eth-bnb", apr: 0.25}
                   ],
                   position_usd: 10_000,
                   gas_cost_usd: 0.5
                 },
                 @ctx
               )

      assert result.best_pool == "cake-bnb"
      assert result.position_usd == 10_000
      assert Enum.map(result.pools, & &1.id) == ["cake-bnb", "eth-bnb", "usdt-busd"]
      assert Enum.map(result.pools, & &1.rank) == [1, 2, 3]

      [first, _second, third] = result.pools
      assert first.apr == 0.4
      assert_in_delta first.apy, ApyOptimizerPrism.apy(0.4, 365), 1.0e-12
      assert third.tvl_usd == 5_000_000
      refute Map.has_key?(first, :tvl_usd)
    end

    test "picks the compounding frequency with the best net APY" do
      assert {:ok, %{pools: [pool]}} =
               ApyOptimizerPrism.handler(
                 %{pools: [%{id: 1, apr: 0.5}], position_usd: 10_000, gas_cost_usd: 5},
                 @ctx
               )

      candidates = [1, 2, 4, 12, 24, 52, 104, 365, 730, 1460]
      net = fn n -> ApyOptimizerPrism.apy(0.5, n) - n * 5 / 10_000 end
      expected = Enum.max_by(candidates, net)

      assert pool.best_compounds_per_year == expected
      assert_in_delta pool.net_apy, net.(expected), 1.0e-12
      # with $5 gas on $10k, compounding every day is not optimal
      assert pool.best_compounds_per_year < 365
    end

    test "compounds as often as possible when gas is free" do
      assert {:ok, %{pools: [pool]}} =
               ApyOptimizerPrism.handler(
                 %{pools: [%{id: 1, apr: 0.5}], position_usd: 1_000},
                 @ctx
               )

      assert pool.best_compounds_per_year == 1460
    end

    test "never compounds more than once a year when gas dominates" do
      assert {:ok, %{pools: [pool]}} =
               ApyOptimizerPrism.handler(
                 %{pools: [%{id: 1, apr: 0.05}], position_usd: 100, gas_cost_usd: 10},
                 @ctx
               )

      assert pool.best_compounds_per_year == 1
      assert pool.net_apy < 0
    end

    test "gas costs can change the ranking" do
      assert {:ok, result} =
               ApyOptimizerPrism.handler(
                 %{
                   pools: [%{id: "a", apr: 0.3}, %{id: "b", apr: 0.3}],
                   position_usd: 1_000,
                   gas_cost_usd: 1,
                   candidate_frequencies: [1, 12]
                 },
                 @ctx
               )

      assert Enum.all?(result.pools, &(&1.best_compounds_per_year in [1, 12]))
    end

    test "uses compounds_per_year for the reported apy" do
      assert {:ok, %{pools: [pool]}} =
               ApyOptimizerPrism.handler(
                 %{pools: [%{id: 1, apr: 0.5}], position_usd: 1_000, compounds_per_year: 12},
                 @ctx
               )

      assert pool.compounds_per_year == 12
      assert_in_delta pool.apy, ApyOptimizerPrism.apy(0.5, 12), 1.0e-12
    end

    test "accepts string keys" do
      assert {:ok, %{best_pool: "x"}} =
               ApyOptimizerPrism.handler(
                 %{"pools" => [%{"id" => "x", "apr" => 0.2}], "position_usd" => 500},
                 @ctx
               )
    end

    test "validates the input" do
      valid = %{pools: [%{id: 1, apr: 0.1}], position_usd: 100}

      assert {:error, _} = ApyOptimizerPrism.handler(Map.put(valid, :pools, []), @ctx)

      assert {:error, _} =
               ApyOptimizerPrism.handler(Map.put(valid, :pools, [%{id: 1, apr: -0.1}]), @ctx)

      assert {:error, _} = ApyOptimizerPrism.handler(Map.put(valid, :pools, [%{apr: 0.1}]), @ctx)
      assert {:error, _} = ApyOptimizerPrism.handler(Map.put(valid, :pools, ["x"]), @ctx)

      assert {:error, "position_usd must be a positive number"} =
               ApyOptimizerPrism.handler(Map.put(valid, :position_usd, 0), @ctx)

      assert {:error, _} = ApyOptimizerPrism.handler(Map.put(valid, :gas_cost_usd, -1), @ctx)
      assert {:error, _} = ApyOptimizerPrism.handler(Map.put(valid, :compounds_per_year, 0), @ctx)

      assert {:error, _} =
               ApyOptimizerPrism.handler(Map.put(valid, :candidate_frequencies, [0]), @ctx)

      assert {:error, _} =
               ApyOptimizerPrism.handler(Map.put(valid, :candidate_frequencies, []), @ctx)
    end
  end
end
