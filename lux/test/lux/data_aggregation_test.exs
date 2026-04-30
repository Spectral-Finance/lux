defmodule Lux.DataAggregationTest do
  use ExUnit.Case, async: true

  doctest Lux.DataAggregation

  describe "supported_chains/0" do
    test "returns all supported chains" do
      chains = Lux.DataAggregation.supported_chains()

      assert is_map(chains)
      assert Map.has_key?(chains, :ethereum)
      assert Map.has_key?(chains, :polygon)
      assert Map.has_key?(chains, :bsc)
      assert Map.has_key?(chains, :arbitrum)
      assert Map.has_key?(chains, :optimism)
      assert Map.has_key?(chains, :avalanche)
      assert Map.has_key?(chains, :fantom)
    end

    test "each chain has required configuration" do
      chains = Lux.DataAggregation.supported_chains()

      for {_chain, config} <- chains do
        assert Keyword.has_key?(config, :name)
        assert Keyword.has_key?(config, :chain_id)
        assert Keyword.has_key?(config, :symbol)
        assert Keyword.has_key?(config, :default_rpc)
        assert Keyword.has_key?(config, :explorer)
      end
    end
  end

  describe "chain_config/1" do
    test "returns config for valid chain" do
      config = Lux.DataAggregation.chain_config(:ethereum)
      assert config != nil
      assert Keyword.fetch!(config, :chain_id) == 1
    end

    test "returns nil for invalid chain" do
      assert Lux.DataAggregation.chain_config(:invalid_chain) == nil
    end
  end

  describe "normalize/3" do
    test "normalizes block data" do
      block = %{
        "number" => "0x1234567",
        "hash" => "0xABCDEF1234567890",
        "parentHash" => "0x1234567890ABCDEF",
        "timestamp" => "0x645F5A00",
        "gasUsed" => "0x12345",
        "gasLimit" => "0x1FFFFF",
        "miner" => "0xabcdef1234567890abcdef1234567890abcdef12",
        "transactions" => [],
        "size" => "0x500",
        "baseFeePerGas" => "0x3B9ACA00",
        "difficulty" => "0x0"
      }

      result = Lux.DataAggregation.Normalizer.normalize(block, :ethereum, :unified)

      assert result.type == :block
      assert result.chain == :ethereum
      assert result.chain_name == "Ethereum Mainnet"
      assert result.chain_id == 1
      assert result.number == 19_088_743
      assert result.hash == "0xabcdef1234567890"
      assert result.transaction_count == 0
      assert result.timestamp_iso != nil
    end

    test "normalizes transaction data" do
      tx = %{
        "hash" => "0xTXHASH1234567890",
        "blockNumber" => "0x1234567",
        "from" => "0xSENDER1234567890abcdef1234567890abcdef12",
        "to" => "0xRECIPIENT1234567890abcdef1234567890abcdef",
        "value" => "0xDE0B6B3A7640000",  # 1 ETH in wei
        "gas" => "0x5208",
        "gasPrice" => "0x3B9ACA00",
        "nonce" => "0x1",
        "input" => "0x",
        "transactionIndex" => "0x0"
      }

      result = Lux.DataAggregation.Normalizer.normalize(tx, :ethereum, :unified)

      assert result.type == :transaction
      assert result.chain == :ethereum
      assert result.value == 1_000_000_000_000_000_000
      assert String.contains?(result.value_ether, "1.0")
      assert result.gas == 21_000
    end

    test "normalizes event data" do
      event = %{
        chain: :ethereum,
        contract_address: "0xCONTRACT1234567890abcdef1234567890abcdef",
        transaction_hash: "0xTXHASH1234567890",
        log_index: 0,
        block_number: 19_088_743,
        block_hash: "0xBLOCKHASH1234567890",
        topics: ["0xEVENTSIG1234567890", "0xPARAM1"],
        data: "0xDATA1234"
      }

      result = Lux.DataAggregation.Normalizer.normalize(event, :ethereum, :unified)

      assert result.type == :event
      assert result.chain == :ethereum
      assert length(result.topics) == 2
      assert result.decoded != nil
    end
  end

  describe "data store operations" do
    setup do
      # Start the data store
      {:ok, pid} = Lux.DataAggregation.DataStore.start_link()
      %{pid: pid}
    end

    test "stores and queries blocks", %{pid: _pid} do
      block = %{
        "hash" => "0xTESTBLOCK123",
        "number" => "0x1",
        "parentHash" => "0x0",
        "timestamp" => "0x645F5A00",
        "gasUsed" => "0x0",
        "gasLimit" => "0x1FFFFF",
        "miner" => "0x0000000000000000000000000000000000000000",
        "transactions" => [],
        "size" => "0x100"
      }

      :ok = Lux.DataAggregation.DataStore.store_block(:ethereum, block, 1)

      blocks = Lux.DataAggregation.DataStore.query_blocks(:ethereum)
      assert length(blocks) == 1
      assert hd(blocks).number == 1
    end

    test "stores and queries transactions", %{pid: _pid} do
      tx = %{
        "hash" => "0xTESTTX1234567890",
        "blockNumber" => "0x1",
        "from" => "0xSENDER1234567890abcdef1234567890abcdef12",
        "to" => "0xRECIPIENT1234567890abcdef1234567890abcdef",
        "value" => "0x0",
        "gas" => "0x5208",
        "gasPrice" => "0x3B9ACA00",
        "nonce" => "0x0",
        "input" => "0x",
        "transactionIndex" => "0x0"
      }

      :ok = Lux.DataAggregation.DataStore.store_transaction(:ethereum, tx, 1)

      txs = Lux.DataAggregation.DataStore.query_transactions(:ethereum)
      assert length(txs) == 1
      assert hd(txs).hash == "0xtesttx1234567890"
    end

    test "stores and queries events", %{pid: _pid} do
      event = %{
        chain: :ethereum,
        contract_address: "0xCONTRACT1234567890abcdef1234567890abcdef",
        transaction_hash: "0xTESTTX1234567890",
        log_index: 0,
        block_number: 1,
        block_hash: "0xTESTBLOCK123",
        address: "0xCONTRACT1234567890abcdef1234567890abcdef",
        topics: ["0xEVENTSIG"],
        data: "0x",
        removed: false
      }

      :ok = Lux.DataAggregation.DataStore.store_event(event)

      events = Lux.DataAggregation.DataStore.query_events(
        :ethereum,
        "0xCONTRACT1234567890abcdef1234567890abcdef"
      )
      assert length(events) == 1
      assert hd(events).block_number == 1
    end

    test "returns chain stats", %{pid: _pid} do
      stats = Lux.DataAggregation.DataStore.chain_stats(:ethereum)

      assert stats.chain == :ethereum
      assert is_integer(stats.blocks_stored)
      assert is_integer(stats.transactions_stored)
      assert is_integer(stats.events_stored)
    end
  end
end
