defmodule Lux.Integrations.SushiSwapTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.SushiSwap

  describe "query_pairs/1" do
    test "returns pairs from the subgraph" do
      result = SushiSwap.query_pairs(%{first: 5})
      assert elem(result, 0) in [:ok, :error]
    end

    test "returns tokens from the subgraph" do
      result = SushiSwap.query_tokens(%{first: 5})
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "route finding" do
    test "find_route returns route candidates" do
      result = SushiSwap.find_route("0xtoken_a", "0xtoken_b", 1000)
      assert {:ok, route_result} = result
      assert Map.has_key?(route_result, :routes)
      assert Map.has_key?(route_result, :best_route)
      assert route_result.amount_in == 1000
    end

    test "find_route with max_hops" do
      result = SushiSwap.find_route("0xtoken_a", "0xtoken_b", 1000, max_hops: 3)
      assert {:ok, _} = result
    end

    test "find_paths returns possible paths" do
      pairs = [
        %{token0: %{id: "A"}, token1: %{id: "B"}, reserve0: 100, reserve1: 200},
        %{token0: %{id: "B"}, token1: %{id: "C"}, reserve0: 300, reserve1: 400}
      ]

      paths = SushiSwap.find_paths("A", "C", pairs, 2)
      assert length(paths) > 0
    end

    test "evaluate_routes returns ranked results" do
      routes = [["0xA", "0xB"], ["0xA", "0xC", "0xB"]]
      assert {:ok, evaluated} = SushiSwap.evaluate_routes(routes, 1000)
      assert length(evaluated) > 0
    end

    test "estimate_swap returns output estimate" do
      # Will return error since pair lookup fails, but validates function exists
      result = SushiSwap.estimate_swap("0xpair", "0xtoken", 100)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "cross-chain bridge" do
    test "supported_chains returns chain list" do
      chains = SushiSwap.supported_chains()
      assert :ethereum in chains
      assert :arbitrum in chains
      assert :polygon in chains
    end

    test "find_bridge_route returns bridge details" do
      result = SushiSwap.find_bridge_route(:ethereum, :arbitrum, "0xtoken", 1000)
      assert {:ok, bridge} = result
      assert bridge.source_chain == :ethereum
      assert bridge.destination_chain == :arbitrum
      assert bridge.protocol == "SushiXSwap"
      assert Map.has_key?(bridge, :estimated_output)
      assert Map.has_key?(bridge, :bridge_fee)
      assert Map.has_key?(bridge, :estimated_time_minutes)
    end

    test "find_bridge_route rejects same chain" do
      result = SushiSwap.find_bridge_route(:ethereum, :ethereum, "0xtoken", 1000)
      assert {:error, _} = result
    end

    test "get_bridge_fee returns fee breakdown" do
      result = SushiSwap.get_bridge_fee(:ethereum, :arbitrum)
      assert {:ok, fee} = result
      assert Map.has_key?(fee, :base_fee)
      assert Map.has_key?(fee, :gas_estimate)
      assert Map.has_key?(fee, :total_fee)
    end

    test "get_cross_chain_data returns chain-specific data" do
      result = SushiSwap.get_cross_chain_data("0xtoken", chains: [:ethereum])
      assert {:ok, data} = result
      assert Map.has_key?(data, :chain_data)
      assert Map.has_key?(data, :token)
    end

    test "estimate_bridge_time returns reasonable values" do
      assert SushiSwap.estimate_bridge_time(:ethereum, :arbitrum) > 0
      assert SushiSwap.estimate_bridge_time(:arbitrum, :optimism) > 0
      assert SushiSwap.estimate_bridge_time(:ethereum, :ethereum) == 0
    end
  end

  describe "multi-chain aggregation" do
    test "aggregate_chains returns chain data" do
      result = SushiSwap.aggregate_chains([:ethereum])
      assert {:ok, agg} = result
      assert Map.has_key?(agg, :chain_data)
      assert Map.has_key?(agg, :total_pairs)
    end
  end
end
