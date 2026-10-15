defmodule Lux.Web3.MultiChainAggregatorTest do
  use ExUnit.Case, async: true
  alias Lux.Web3.MultiChainAggregator

  setup do
    {:ok, pid} = MultiChainAggregator.start_link(name: :"aggregator_#{System.unique_integer([:positive])}")
    %{server: pid}
  end

  test "normalizes and aggregates blocks and contract events across Ethereum, Base, and Polygon", %{server: server} do
    eth_block = %{
      "number" => "0x1312d00",
      "hash" => "0xAbC123",
      "parentHash" => "0xDeF456",
      "timestamp" => "0x670e0000",
      "transactions" => ["0x1", "0x2"]
    }

    base_block = %{
      "number" => "0x3232577",
      "hash" => "0xBa5e999",
      "parentHash" => "0xBa5e888",
      "timestamp" => "0x670e0010",
      "transactions" => ["0x3"]
    }

    assert {:ok, 1} = MultiChainAggregator.ingest_blocks(server, 1, [eth_block])
    assert {:ok, 1} = MultiChainAggregator.ingest_blocks(server, 8453, [base_block])

    assert {:ok, blocks} = MultiChainAggregator.query_blocks(server, %{chain_ids: [1, 8453]})
    assert length(blocks) == 2
    assert hd(blocks).chain_id == 8453
    assert hd(blocks).block_number == 52_635_000 - 2_057

    transfer_topic = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

    raw_logs = [
      %{
        "blockNumber" => "0x3232577",
        "transactionHash" => "0xTxBase1",
        "address" => "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
        "topics" => [transfer_topic],
        "data" => "0x000000000000000000000000000000000000000000000000000000000003d090",
        "logIndex" => "0x0"
      }
    ]

    assert {:ok, 1} = MultiChainAggregator.ingest_events(server, 8453, raw_logs)

    assert {:ok, [event]} =
             MultiChainAggregator.query_events(server, %{
               chain_ids: [8453],
               contract_address: "0x833589fcd6edb6e08f4c7c32d4f71b54bda02913",
               topic0: transfer_topic
             })

    assert event.chain_id == 8453
    assert event.tx_hash == "0xtxbase1"
  end

  test "prunes expired historical events based on chain retention policy", %{server: server} do
    assert {:ok, 1} =
             MultiChainAggregator.ingest_events(server, 1, [
               %{
                 "blockNumber" => "0x10",
                 "transactionHash" => "0xOldTx",
                 "address" => "0x1111111111111111111111111111111111111111",
                 "topics" => ["0xabc"],
                 "data" => "0x",
                 "logIndex" => "0x0"
               }
             ])

    future_time = System.system_time(:second) + 200_000
    assert {:ok, 1} = MultiChainAggregator.prune_expired(server, future_time)
    assert {:ok, []} = MultiChainAggregator.query_events(server)
  end
end
