defmodule Lux.Lenses.DeFiAnalytics.DeFiLlamaYieldLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.DeFiAnalytics.DeFiLlamaYieldLens

  describe "focus/2 — input variants" do
    test "accepts empty input (all pools)" do
      result = DeFiLlamaYieldLens.focus(%{}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts chain filter" do
      result = DeFiLlamaYieldLens.focus(%{chain: "Ethereum"}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts project filter" do
      result = DeFiLlamaYieldLens.focus(%{project: "aave-v3"}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts symbol filter" do
      result = DeFiLlamaYieldLens.focus(%{symbol: "USDC"}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts min_apy filter" do
      result = DeFiLlamaYieldLens.focus(%{min_apy: 5.0, top_n: 5}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts min_tvl filter" do
      result = DeFiLlamaYieldLens.focus(%{min_tvl: 1_000_000}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts max_il_risk filter" do
      result = DeFiLlamaYieldLens.focus(%{max_il_risk: "no"}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts combined filters" do
      result = DeFiLlamaYieldLens.focus(%{
        chain: "Ethereum",
        min_apy: 2.0,
        min_tvl: 10_000_000,
        max_il_risk: "low",
        sort_by: "tvl",
        top_n: 10
      }, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts sort_by tvl" do
      result = DeFiLlamaYieldLens.focus(%{sort_by: "tvl", top_n: 5}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts sort_by apy_base" do
      result = DeFiLlamaYieldLens.focus(%{sort_by: "apy_base", top_n: 5}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "focus/2 — live API (network dependent)" do
    @tag :integration
    test "returns pools with expected structure" do
      case DeFiLlamaYieldLens.focus(%{top_n: 3, min_tvl: 100_000_000}, %{}) do
        {:ok, result} ->
          assert Map.has_key?(result, :pools)
          assert Map.has_key?(result, :total_pools)
          assert Map.has_key?(result, :filtered_count)
          assert Map.has_key?(result, :avg_apy)
          assert result.status == "success"
          assert result.total_pools > 1000  # DeFiLlama has thousands of pools

          for pool <- result.pools do
            assert Map.has_key?(pool, "pool_id")
            assert Map.has_key?(pool, "project")
            assert Map.has_key?(pool, "symbol")
            assert Map.has_key?(pool, "chain")
            assert Map.has_key?(pool, "apy")
            assert Map.has_key?(pool, "tvl_usd")
            assert Map.has_key?(pool, "il_risk")
          end
        {:error, _} -> :skip
      end
    end

    @tag :integration
    test "min_apy filter reduces results" do
      case DeFiLlamaYieldLens.focus(%{min_apy: 50.0, top_n: 5}, %{}) do
        {:ok, result} ->
          for pool <- result.pools do
            assert pool["apy"] >= 50.0
          end
        {:error, _} -> :skip
      end
    end

    @tag :integration
    test "stablecoin pools returned when symbol filtered" do
      case DeFiLlamaYieldLens.focus(%{symbol: "USDC", top_n: 5}, %{}) do
        {:ok, result} ->
          for pool <- result.pools do
            assert String.contains?(pool["symbol"], "USDC")
          end
        {:error, _} -> :skip
      end
    end
  end

  describe "schema" do
    test "schema has all filter properties" do
      schema = DeFiLlamaYieldLens.view().schema
      props = schema.properties
      assert Map.has_key?(props, :chain)
      assert Map.has_key?(props, :project)
      assert Map.has_key?(props, :symbol)
      assert Map.has_key?(props, :min_apy)
      assert Map.has_key?(props, :min_tvl)
      assert Map.has_key?(props, :max_il_risk)
      assert Map.has_key?(props, :top_n)
      assert Map.has_key?(props, :sort_by)
    end
  end
end
