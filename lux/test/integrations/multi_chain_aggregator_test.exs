defmodule Lux.Integrations.MultiChainAggregatorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.MultiChainAggregator

  describe "chain configuration" do
    test "returns default chain config for known chains" do
      config = Aggregator.get_chain_config(:ethereum)
      assert config.chain_id == 1
      assert length(config.rpc_urls) >= 1
    end

    test "returns empty map for unknown chains" do
      config = Aggregator.get_chain_config(:unknown_chain)
      assert config == %{}
    end
  end

  describe "data normalization" do
    alias Lux.Integrations.MultiChainAggregator.Normalizer

    test "normalizes block data" do
      block = %{
        "number" => "0x10",
        "hash" => "0xabc123",
        "parentHash" => "0xdef456",
        "timestamp" => "0x60000000",
        "gasUsed" => "0xf4240",
        "gasLimit" => "0x1e8480",
        "transactions" => ["0xtx1", "0xtx2"],
        "miner" => "0x1234567890abcdef"
      }
      
      normalized = Normalizer.normalize_block(block, :ethereum)
      assert normalized.chain == :ethereum
      assert normalized.number == 16
      assert normalized.hash == "0xabc123"
      assert normalized.transaction_count == 2
    end

    test "normalizes transaction data" do
      tx = %{
        "hash" => "0xtxhash",
        "blockNumber" => "0x10",
        "from" => "0xsender",
        "to" => "0xreceiver",
        "value" => "0xde0b6b3a7640000",
        "gasPrice" => "0x4a817c800",
        "nonce" => "0x5",
        "input" => "0x"
      }

      normalized = Normalizer.normalize_transaction(tx, :base)
      assert normalized.chain == :base
      assert normalized.value_eth == 1.0
      assert normalized.from == "0xsender"
    end

    test "normalizes log entries" do
      log = %{
        "address" => "0xcontract",
        "topics" => ["0xtopic1", "0xtopic2"],
        "data" => "0xdata",
        "blockNumber" => "0x10",
        "transactionHash" => "0xtxhash",
        "logIndex" => "0x0",
        "removed" => false
      }

      normalized = Normalizer.normalize_log_entry(log, :polygon)
      assert normalized.chain == :polygon
      assert normalized.address == "0xcontract"
      assert length(normalized.topics) == 2
    end
  end

  describe "data store" do
    alias Lux.Integrations.MultiChainAggregator.DataStore

    setup do
      DataStore.init_tables(:test_chain)
      on_exit(fn ->
        for t <- [:blocks, :events] do
          try do :ets.delete(:"mca_test_chain_#{t}") catch _, _ -> :ok end
        end
      end)
    end

    test "stores and retrieves blocks" do
      block = %{number: 100, hash: "0xtest"}
      :ok = DataStore.store_block(:test_chain, block)
      {:ok, retrieved} = DataStore.get_block(:test_chain, 100)
      assert retrieved.hash == "0xtest"
    end

    test "returns not_found for missing blocks" do
      assert {:error, :not_found} = DataStore.get_block(:test_chain, 999)
    end
  end
end