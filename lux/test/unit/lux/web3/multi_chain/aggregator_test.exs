defmodule Lux.Web3.MultiChain.AggregatorTest do
  use UnitCase, async: true

  alias Lux.Web3.MultiChain.Aggregator

  @input %{
    chains: [
      %{name: "ethereum", chain_id: 1, rpc_url: "https://example.invalid/eth"},
      %{name: "base", chain_id: 8453, rpc_url: "https://example.invalid/base"}
    ],
    blocks: [
      %{
        chain: "ethereum",
        number: 100,
        hash: "0xaaa",
        timestamp: "2026-06-15T10:00:00Z",
        tx_count: 2
      },
      %{chain: "base", number: 200, hash: "0xbbb", timestamp: "2026-06-15T10:00:02Z", tx_count: 1}
    ],
    transactions: [
      %{
        chain: "ethereum",
        hash: "0xtx1",
        block_number: 100,
        from: "0xabc",
        to: "0xdef",
        gas_used: 21_000,
        status: "ok"
      },
      %{
        chain: "base",
        hash: "0xtx2",
        block_number: 200,
        from: "0xabc",
        to: "0x123",
        gas_used: 30_000,
        status: "ok"
      }
    ],
    events: [
      %{
        chain: "ethereum",
        address: "0xContract",
        topic0: "0xTopic",
        event_name: "Transfer",
        block_number: 100,
        tx_hash: "0xtx1",
        log_index: 0
      },
      %{
        chain: "base",
        address: "0xContract",
        topic0: "0xTopic",
        event_name: "Swap",
        block_number: 200,
        tx_hash: "0xtx2",
        log_index: 0
      }
    ]
  }

  test "builds a normalized multi-chain snapshot" do
    assert {:ok, snapshot} = Aggregator.snapshot(@input)
    assert length(snapshot.chains) == 2
    assert snapshot.latest_blocks["ethereum"].number == 100
    assert snapshot.tx_counts_by_chain == %{"ethereum" => 1, "base" => 1}
    assert snapshot.event_counts == %{"Transfer" => 1, "Swap" => 1}
  end

  test "filters events by chain and event name" do
    {:ok, snapshot} = Aggregator.snapshot(@input)

    result = Aggregator.query(snapshot, chain: "base", event_name: "Swap")

    assert result.count == 1
    assert hd(result.events).chain == "base"
  end

  test "builds RPC plans for latest blocks and event filters" do
    plan =
      Aggregator.rpc_plan(
        [%{name: "base", rpc_url: "https://example.invalid/base"}],
        event_filters: [
          %{address: "0xContract", topics: ["0xTopic"], from_block: "0x1", to_block: "latest"}
        ]
      )

    assert [%{method: "eth_blockNumber"}, %{method: "eth_getLogs"}] = plan
    assert hd(plan).purpose == "latest_block"
  end
end
