defmodule Lux.Web3.DataNormalizerTest do
  use ExUnit.Case, async: true
  alias Lux.Web3.DataNormalizer

  describe "normalize_chain/1" do
    test "normalizes EVM chain names" do
      assert DataNormalizer.normalize_chain("ethereum") == "ethereum"
      assert DataNormalizer.normalize_chain("ETH") == "ethereum"
      assert DataNormalizer.normalize_chain("bsc") == "bsc"
      assert DataNormalizer.normalize_chain("binance_smart_chain") == "bsc"
      assert DataNormalizer.normalize_chain("polygon") == "polygon"
      assert DataNormalizer.normalize_chain("arbitrum") == "arbitrum"
      assert DataNormalizer.normalize_chain(:ethereum) == "ethereum"
    end
  end

  describe "normalize_block/2" do
    test "standardizes raw EVM block data" do
      raw = %{
        "number" => "0x1b4",
        "hash" => "0xABC123",
        "parentHash" => "0xDEF456",
        "timestamp" => "0x60000000",
        "miner" => "0x1111222233334444555566667777888899990000",
        "gasLimit" => "0x1c9c380",
        "gasUsed" => "0x5208",
        "baseFeePerGas" => "0x7",
        "transactions" => [
          %{
            "hash" => "0xTX111",
            "from" => "0xAAAA",
            "to" => "0xBBBB",
            "value" => "0xde0b6b3a7640000"
          }
        ]
      }

      normalized = DataNormalizer.normalize_block(raw, "ethereum")

      assert normalized.chain == "ethereum"
      assert normalized.number == 436
      assert normalized.hash == "0xabc123"
      assert normalized.parent_hash == "0xdef456"
      assert normalized.timestamp == 1610612736
      assert is_binary(normalized.timestamp_iso)
      assert normalized.miner == "0x1111222233334444555566667777888899990000"
      assert normalized.gas_limit == 30000000
      assert normalized.gas_used == 21000
      assert normalized.base_fee_per_gas == 7
      assert length(normalized.transactions) == 1

      [tx] = normalized.transactions
      assert tx.hash == "0xtx111"
      assert tx.from == "0xaaaa"
      assert tx.to == "0xbbbb"
      assert tx.value == 1000000000000000000
    end

    test "handles block with transaction hashes list" do
      raw = %{
        "number" => 100,
        "hash" => "0x123",
        "transactions" => ["0xabc", "0xdef"]
      }

      normalized = DataNormalizer.normalize_block(raw, "polygon")

      assert normalized.chain == "polygon"
      assert normalized.number == 100
      assert normalized.transactions == ["0xabc", "0xdef"]
    end
  end

  describe "normalize_transaction/2" do
    test "standardizes raw EVM transaction data" do
      raw = %{
        "hash" => "0xTXHASH123",
        "blockNumber" => "0x64",
        "blockHash" => "0xBLOCK123",
        "from" => "0xSENDER",
        "to" => "0xRECEIVER",
        "value" => "0x10",
        "gas" => "0x5208",
        "gasPrice" => "0x4a817c800",
        "input" => "0xa9059cbb",
        "nonce" => "0x5",
        "transactionIndex" => "0x0",
        "type" => "0x2"
      }

      normalized = DataNormalizer.normalize_transaction(raw, "arbitrum")

      assert normalized.chain == "arbitrum"
      assert normalized.hash == "0xtxhash123"
      assert normalized.block_number == 100
      assert normalized.from == "0xsender"
      assert normalized.to == "0xreceiver"
      assert normalized.value == 16
      assert normalized.gas == 21000
      assert normalized.gas_price == 20000000000
      assert normalized.input == "0xa9059cbb"
      assert normalized.nonce == 5
      assert normalized.type == 2
    end
  end

  describe "normalize_log/2" do
    test "standardizes raw EVM event log data" do
      raw = %{
        "address" => "0xCONTRACTADDRESS",
        "topics" => [
          "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          "0x000000000000000000000000aaaa",
          "0x000000000000000000000000bbbb"
        ],
        "data" => "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
        "blockNumber" => "0x3e8",
        "blockHash" => "0xBHASH",
        "transactionHash" => "0xTHASH",
        "transactionIndex" => "0x1",
        "logIndex" => "0x4",
        "removed" => false
      }

      normalized = DataNormalizer.normalize_log(raw, "bsc")

      assert normalized.chain == "bsc"
      assert normalized.address == "0xcontractaddress"
      assert length(normalized.topics) == 3
      assert Enum.at(normalized.topics, 0) == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      assert normalized.block_number == 1000
      assert normalized.transaction_hash == "0xthash"
      assert normalized.log_index == 4
      assert normalized.removed == false
    end
  end
end
