defmodule Lux.Web3.Multichain.AggregatorTest do
  use ExUnit.Case, async: false

  alias Lux.Web3.Multichain.Aggregator
  alias Lux.Web3.Multichain.Schemas.{Block, Event, Transaction}

  describe "Multi-Chain Aggregator Engine (#74)" do
    setup do
      name = :"aggregator_test_#{:erlang.unique_integer([:positive])}"
      {:ok, pid} = Aggregator.start_link(name: name, retention: %{max_blocks_per_chain: 5})

      raw_block_eth = %{
        number: 1000,
        hash: "0xeth1000",
        timestamp: 1_700_000_000,
        transactions: [
          %{
            hash: "0xtx1",
            blockNumber: 1000,
            from: "0xalice",
            to: "0xbob",
            value: 500,
            status: 1
          }
        ]
      }

      raw_block_arb = %{
        number: 5000,
        hash: "0xarb5000",
        timestamp: 1_700_000_100,
        transactions: [
          %{
            hash: "0xtx2",
            blockNumber: 5000,
            from: "0xbob",
            to: "0xcharlie",
            value: 250,
            status: 1
          }
        ]
      }

      %{server: pid, raw_block_eth: raw_block_eth, raw_block_arb: raw_block_arb}
    end

    test "ingests blocks across multiple chains and queries them", %{
      server: s,
      raw_block_eth: b1,
      raw_block_arb: b2
    } do
      assert {:ok, %Block{chain: :ethereum}} = Aggregator.ingest_block(s, :ethereum, b1)
      assert {:ok, %Block{chain: :arbitrum}} = Aggregator.ingest_block(s, :arbitrum, b2)

      # Query all blocks
      all_blocks = Aggregator.query_blocks(s, %{})
      assert length(all_blocks) == 2

      # Query by chain
      eth_blocks = Aggregator.query_blocks(s, %{chain: :ethereum})
      assert length(eth_blocks) == 1
      assert hd(eth_blocks).number == 1000

      arb_blocks = Aggregator.query_blocks(s, %{chain: :arbitrum})
      assert length(arb_blocks) == 1
      assert hd(arb_blocks).number == 5000
    end

    test "indexes and queries transactions across chains", %{server: s, raw_block_eth: b1} do
      Aggregator.ingest_block(s, :ethereum, b1)

      txs = Aggregator.query_transactions(s, %{from: "0xalice"})
      assert length(txs) == 1
      [tx] = txs
      assert tx.hash == "0xtx1"
      assert tx.value == 500
      assert tx.status == :success
    end

    test "ingests events and supports real-time PubSub streaming", %{server: s} do
      # Subscribe calling process to ethereum events
      Aggregator.subscribe(s, {:events, :ethereum})

      raw_event = %{
        address: "0xtoken",
        transactionHash: "0xtx1",
        blockNumber: 1000,
        topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],
        data: "0x10"
      }

      assert {:ok, %Event{} = ev} = Aggregator.ingest_event(s, :ethereum, raw_event)

      # Verify PubSub message received
      assert_receive {:new_event, :ethereum, received_ev}, 1000
      assert received_ev.tx_hash == "0xtx1"

      # Query event
      events = Aggregator.query_events(s, %{chain: :ethereum, contract_address: "0xtoken"})
      assert length(events) == 1
    end

    test "enforces max_blocks_per_chain retention policy", %{server: s} do
      Enum.each(1..10, fn n ->
        block = %{
          number: n,
          hash: "0xhash_#{n}",
          timestamp: 1_700_000_000 + n,
          transactions: []
        }

        Aggregator.ingest_block(s, :polygon, block)
      end)

      # Capacity is 5
      blocks = Aggregator.query_blocks(s, %{chain: :polygon, limit: 100})
      assert length(blocks) == 5
      # Kept highest block numbers (6 to 10)
      numbers = Enum.map(blocks, & &1.number)
      assert numbers == [10, 9, 8, 7, 6]
    end

    test "reports engine metrics", %{server: s, raw_block_eth: b1} do
      Aggregator.ingest_block(s, :ethereum, b1)
      metrics = Aggregator.get_metrics(s)
      assert metrics.total_chains >= 1
      assert metrics.total_blocks >= 1
      assert metrics.total_transactions >= 1
    end
  end
end
