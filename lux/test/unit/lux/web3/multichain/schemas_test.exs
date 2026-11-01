defmodule Lux.Web3.Multichain.SchemasTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Multichain.Schemas
  alias Lux.Web3.Multichain.Schemas.{Block, Event, Transaction}

  describe "Multi-Chain Schemas & Normalization (#74)" do
    test "normalizes raw JSON-RPC block with hex values" do
      raw_block = %{
        "number" => "0x10d4f",
        "hash" => "0xAbCdEf1234567890",
        "parentHash" => "0x1234567890abcdef",
        "timestamp" => "0x66f00123",
        "gasUsed" => "0x5208",
        "gasLimit" => "0x1c9c380",
        "baseFeePerGas" => "0x3b9aca00",
        "transactions" => [
          %{
            "hash" => "0x9876543210fedcba",
            "blockNumber" => "0x10d4f",
            "from" => "0x1111111111111111111111111111111111111111",
            "to" => "0x2222222222222222222222222222222222222222",
            "value" => "0xde0b6b3a7640000",
            "gasPrice" => "0x4a817c800",
            "status" => "0x1"
          }
        ]
      }

      assert {:ok, %Block{} = block} = Schemas.normalize_block(raw_block, :ethereum, 1)
      assert block.chain_id == 1
      assert block.chain == :ethereum
      assert block.number == 68943
      assert block.hash == "0xabcdef1234567890"
      assert block.gas_used == 21000
      assert block.transaction_count == 1

      [tx] = block.transactions
      assert %Transaction{} = tx
      assert tx.hash == "0x9876543210fedcba"
      assert tx.status == :success
      assert tx.value == 1_000_000_000_000_000_000
    end

    test "normalizes transaction status properly" do
      base_tx = %{
        "hash" => "0xaaa",
        "blockNumber" => 100,
        "from" => "0xbbb",
        "value" => 0
      }

      {:ok, tx_success} = Schemas.normalize_transaction(Map.put(base_tx, "status", 1), :arbitrum, 42161)
      assert tx_success.status == :success

      {:ok, tx_revert} = Schemas.normalize_transaction(Map.put(base_tx, "status", 0), :arbitrum, 42161)
      assert tx_revert.status == :reverted

      {:ok, tx_pending} = Schemas.normalize_transaction(Map.put(base_tx, "status", nil), :arbitrum, 42161)
      assert tx_pending.status == :pending
    end

    test "normalizes event log with topics" do
      raw_log = %{
        "address" => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        "transactionHash" => "0xccc",
        "blockNumber" => "0x64",
        "logIndex" => "0x2",
        "topics" => [
          "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          "0x0000000000000000000000001111111111111111111111111111111111111111",
          "0x0000000000000000000000002222222222222222222222222222222222222222"
        ],
        "data" => "0x00000000000000000000000000000000000000000000000000000000000f4240"
      }

      assert {:ok, %Event{} = event} = Schemas.normalize_event(raw_log, :ethereum, 1)
      assert event.chain == :ethereum
      assert event.contract_address == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
      assert event.block_number == 100
      assert event.log_index == 2
      assert length(event.topics) == 3
    end

    test "parse_int handles decimal, hex, and edge cases" do
      assert Schemas.parse_int(42) == 42
      assert Schemas.parse_int("42") == 42
      assert Schemas.parse_int("0x2a") == 42
      assert Schemas.parse_int("0X2A") == 42
      assert Schemas.parse_int(nil) == nil
      assert Schemas.parse_int("invalid") == nil
    end
  end
end
