defmodule Lux.Integrations.MultiChain.AggregatorTest do
  use UnitCase, async: true

  alias Lux.Integrations.MultiChain.Aggregator

  @usdc "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
  @transfer_topic "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  describe "normalize_chains/1" do
    test "normalizes built-in EVM chains" do
      assert {:ok, [ethereum, polygon]} = Aggregator.normalize_chains(["ethereum", :polygon])

      assert ethereum.chain_id == 1
      assert ethereum.chain_id_hex == "0x1"
      assert polygon.chain_id == 137
      assert polygon.native_symbol == "MATIC"
    end

    test "supports custom chain maps" do
      assert {:ok, [chain]} =
               Aggregator.normalize_chains([
                 %{key: "test-rollup", chain_id: 12_345, rpc_url: "http://localhost:8545"}
               ])

      assert chain.key == "test-rollup"
      assert chain.chain_id_hex == "0x3039"
      assert chain.rpc_url == "http://localhost:8545"
    end

    test "rejects unsupported chains" do
      assert {:error, {:unsupported_chain, "unknown"}} = Aggregator.normalize_chains(["unknown"])
    end
  end

  describe "latest_block_requests/1" do
    test "builds JSON-RPC requests for each chain" do
      assert {:ok, [request]} = Aggregator.latest_block_requests(["base"])

      assert request.chain == "base"
      assert request.chain_id == 8453
      assert request.request.method == "eth_blockNumber"
      assert request.request.params == []
    end
  end

  describe "event_filter/4" do
    test "builds an eth_getLogs request with normalized address and block tags" do
      assert {:ok, request} =
               Aggregator.event_filter("ethereum", String.upcase(@usdc), @transfer_topic, %{
                 from_block: 20_000_000,
                 to_block: "latest"
               })

      [filter] = request.request.params

      assert request.request.method == "eth_getLogs"
      assert filter.address == @usdc
      assert filter.fromBlock == "0x1312d00"
      assert filter.toBlock == "latest"
      assert filter.topics == [@transfer_topic]
    end
  end

  describe "block and log normalization" do
    test "normalizes latest-block responses and aggregates lag" do
      responses = [
        %{chain: "ethereum", response: %{"result" => "0x64"}},
        %{chain: "polygon", response: %{"result" => "0x5f"}}
      ]

      aggregate = Aggregator.aggregate_latest_blocks(responses)

      assert aggregate.highest_block == 100
      assert aggregate.lowest_block == 95
      assert aggregate.lag_by_chain == %{"ethereum" => 0, "polygon" => 5}
    end

    test "normalizes EVM logs" do
      assert {:ok, log} =
               Aggregator.normalize_log("base", %{
                 "address" => @usdc,
                 "topics" => [@transfer_topic],
                 "data" => "0x",
                 "transactionHash" => "0xabc",
                 "blockHash" => "0xdef",
                 "blockNumber" => "0x2a",
                 "logIndex" => "0x1"
               })

      assert log.chain == "base"
      assert log.block_number == 42
      assert log.log_index == 1
      assert log.topics == [@transfer_topic]
    end
  end

  describe "query_events/2" do
    test "filters normalized events by chain address topic and block range" do
      events = [
        %{chain: "ethereum", address: @usdc, topics: [@transfer_topic], block_number: 100},
        %{chain: "base", address: @usdc, topics: [@transfer_topic], block_number: 101},
        %{chain: "ethereum", address: @usdc, topics: ["0xother"], block_number: 102}
      ]

      assert [%{chain: "ethereum", block_number: 100}] =
               Aggregator.query_events(events, %{
                 chain: "ethereum",
                 address: @usdc,
                 topic: @transfer_topic,
                 from_block: 99,
                 to_block: 101
               })
    end
  end

  describe "subscription_plan/3" do
    test "creates a request for every chain/filter pair" do
      assert {:ok, plan} =
               Aggregator.subscription_plan(
                 ["ethereum", "base"],
                 [%{name: "usdc", address: @usdc, topic: @transfer_topic}],
                 %{poll_interval_ms: 10_000}
               )

      assert plan.mode == :poll
      assert plan.poll_interval_ms == 10_000
      assert length(plan.chains) == 2
      assert length(plan.rpc_requests) == 2
      assert plan.retention.checkpoint_every_blocks == 1_000
    end
  end
end
