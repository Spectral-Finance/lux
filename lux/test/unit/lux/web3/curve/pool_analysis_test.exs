defmodule Lux.Web3.Curve.PoolAnalysisTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Web3.Curve.PoolAnalysis

  @virtual_price 1_000_000_000_000_000_000

  @max_uint 115_792_089_237_316_195_423_570_985_008_687_907_853_269_984_665_640_564_039_457_584_007_913_129_639_935

  @balanced %{
    address: "0xaaa",
    balances: [1_000_000, 1_000_000, 1_000_000],
    virtual_price: @virtual_price,
    fee: 1_000_000,
    crv_reward_rate: 1_000_000_000_000_000_000
  }

  @imbalanced %{
    address: "0xbbb",
    balances: [9_000_000, 1_000_000],
    virtual_price: @virtual_price,
    fee: 4_000_000
  }

  describe "happy path: pool analysis and selection" do
    test "analyze/1 scores a balanced, high-reward pool as provide_liquidity" do
      assert {:ok, analysis} = PoolAnalysis.analyze(@balanced)
      assert analysis.total_liquidity == 3_000_000
      assert analysis.imbalance_bps == 0
      assert analysis.fee_bps == 1
      assert analysis.reward_bps == 10_000
      assert analysis.recommendation == :provide_liquidity
      assert analysis.score == 29_999
    end

    test "rank/1 orders pools from best to worst" do
      assert {:ok, [best, worst]} = PoolAnalysis.rank([@imbalanced, @balanced])
      assert best.address == "0xaaa"
      assert worst.address == "0xbbb"
      assert best.score > worst.score
    end

    test "select_best/1 returns the highest scoring pool" do
      assert {:ok, best} = PoolAnalysis.select_best([@imbalanced, @balanced])
      assert best.address == "0xaaa"
    end
  end

  describe "null input: handled with a typed validation error" do
    test "analyze/1 rejects nil instead of crashing" do
      assert {:error, :invalid_pool} = PoolAnalysis.analyze(nil)
    end

    test "rank/1 and select_best/1 reject nil" do
      assert {:error, :invalid_pools} = PoolAnalysis.rank(nil)
      assert {:error, :invalid_pools} = PoolAnalysis.select_best(nil)
    end
  end

  describe "empty input: rejected with a clear diagnostic" do
    test "analyze/1 rejects an empty balance list" do
      assert {:error, :empty_balances} = PoolAnalysis.analyze(%{balances: []})
    end

    test "analyze/1 rejects zeroed liquidity" do
      pool = %{balances: [0, 0], virtual_price: 1, fee: 0}
      assert {:error, :empty_liquidity} = PoolAnalysis.analyze(pool)
    end

    test "rank/1 and select_best/1 reject an empty collection" do
      assert {:error, :no_pools} = PoolAnalysis.rank([])
      assert {:error, :no_pools} = PoolAnalysis.select_best([])
    end
  end

  describe "boundary limits: strict half-open evaluation" do
    test "a perfectly balanced pool has zero imbalance at the lower bound" do
      assert {:ok, %{imbalance_bps: 0}} = PoolAnalysis.analyze(@balanced)
    end

    test "the maximum fee consumes the whole fee budget" do
      pool = %{balances: [1, 1], virtual_price: 1, fee: 10_000_000_000}
      assert {:ok, %{fee_bps: 10_000}} = PoolAnalysis.analyze(pool)
    end

    test "maximum uint256 balances are accepted at the upper bound" do
      pool = %{balances: [@max_uint, @max_uint], virtual_price: 1, fee: 0}
      assert {:ok, %{imbalance_bps: 0}} = PoolAnalysis.analyze(pool)
    end
  end

  describe "negative: malformed data is refused" do
    test "missing balances are refused" do
      assert {:error, :missing_balances} = PoolAnalysis.analyze(%{virtual_price: 1, fee: 0})
    end

    test "a negative balance is refused" do
      pool = %{balances: [-1, 1], virtual_price: 1, fee: 0}
      assert {:error, :invalid_balance} = PoolAnalysis.analyze(pool)
    end

    test "a non-positive virtual price is refused" do
      pool = %{balances: [1, 1], virtual_price: 0, fee: 0}
      assert {:error, :invalid_virtual_price} = PoolAnalysis.analyze(pool)
    end

    test "a fee above the native maximum is refused" do
      pool = %{balances: [1, 1], virtual_price: 1, fee: 10_000_000_001}
      assert {:error, :invalid_fee} = PoolAnalysis.analyze(pool)
    end

    test "a negative reward rate is refused" do
      pool = %{balances: [1, 1], virtual_price: 1, fee: 0, crv_reward_rate: -1}
      assert {:error, :invalid_reward_rate} = PoolAnalysis.analyze(pool)
    end

    test "a batch containing an invalid pool is rejected as a whole" do
      assert {:error, :invalid_balance} = PoolAnalysis.rank([@balanced, %{balances: [-5]}])
    end
  end

  describe "concurrency: simultaneous analysis of the same pool" do
    test "concurrent analyses are consistent" do
      results =
        1..20
        |> Enum.map(fn _ -> Task.async(fn -> PoolAnalysis.analyze(@balanced) end) end)
        |> Task.await_many(30_000)

      assert length(Enum.uniq(results)) == 1
      assert Enum.all?(results, &match?({:ok, %{score: 29_999}}, &1))
    end
  end
end
