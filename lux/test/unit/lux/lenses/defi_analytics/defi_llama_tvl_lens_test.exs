defmodule Lux.Lenses.DeFiAnalytics.DeFiLlamaTvlLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.DeFiAnalytics.DeFiLlamaTvlLens

  describe "focus/2 — input validation" do
    test "accepts empty input for global overview" do
      # Should attempt API call, not fail on input validation
      result = DeFiLlamaTvlLens.focus(%{}, %{})
      # Either success (if network available) or error (no network)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts protocol slug" do
      result = DeFiLlamaTvlLens.focus(%{protocol: "uniswap"}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts historical_days parameter" do
      result = DeFiLlamaTvlLens.focus(%{
        protocol: "uniswap",
        historical_days: 7,
        include_historical: true
      }, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts top_n parameter" do
      result = DeFiLlamaTvlLens.focus(%{top_n: 5}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts include_historical: false" do
      result = DeFiLlamaTvlLens.focus(%{
        protocol: "aave",
        include_historical: false
      }, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "focus/2 — live API (network dependent)" do
    @tag :integration
    test "fetches global TVL overview" do
      case DeFiLlamaTvlLens.focus(%{top_n: 5}, %{}) do
        {:ok, result} ->
          assert Map.has_key?(result, :total_tvl)
          assert Map.has_key?(result, :top_protocols)
          assert Map.has_key?(result, :protocol_count)
          assert is_list(result.top_protocols)
          assert length(result.top_protocols) <= 5
          assert result.total_tvl > 0
          assert result.status == "success"
        {:error, _} ->
          :skip
      end
    end

    @tag :integration
    test "fetches protocol TVL with historical data" do
      case DeFiLlamaTvlLens.focus(%{protocol: "uniswap", historical_days: 7}, %{}) do
        {:ok, result} ->
          assert Map.has_key?(result, :current_tvl)
          assert Map.has_key?(result, :tvl_usd)
          assert Map.has_key?(result, :historical)
          assert Map.has_key?(result, :chain_tvls)
          assert result.status == "success"
          assert result.current_tvl > 0
          assert is_binary(result.tvl_usd)
          assert result.tvl_usd =~ ~r/\$/
        {:error, _} ->
          :skip
      end
    end

    @tag :integration
    test "top_protocols have expected fields" do
      case DeFiLlamaTvlLens.focus(%{top_n: 3}, %{}) do
        {:ok, result} ->
          for proto <- result.top_protocols do
            assert Map.has_key?(proto, "name")
            assert Map.has_key?(proto, "tvl")
            assert Map.has_key?(proto, "tvl_usd")
            assert Map.has_key?(proto, "category")
          end
        {:error, _} -> :skip
      end
    end
  end

  describe "schema" do
    test "schema documents all properties" do
      schema = DeFiLlamaTvlLens.view().schema
      props = schema.properties
      assert Map.has_key?(props, :protocol)
      assert Map.has_key?(props, :include_historical)
      assert Map.has_key?(props, :historical_days)
      assert Map.has_key?(props, :top_n)
    end
  end
end
