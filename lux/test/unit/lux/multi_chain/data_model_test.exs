defmodule Lux.MultiChain.DataModelTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Lux.MultiChain.DataModel.{Block, Event, GasPrice, TokenBalance, Transaction}

  describe "Block" do
    test "creates a block struct with all fields" do
      block = %Block{
        chain: :ethereum,
        chain_id: 1,
        number: 18_000_000,
        hash: "0xabc",
        parent_hash: "0xdef",
        timestamp: ~U[2023-09-01 00:00:00Z],
        miner: "0xminer",
        gas_used: 15_000_000,
        gas_limit: 30_000_000,
        base_fee_per_gas: 20_000_000_000,
        transaction_count: 150,
        size: 50_000
      }

      assert block.chain == :ethereum
      assert block.number == 18_000_000
    end

    test "creates a block with default values" do
      block = %Block{chain: :polygon, chain_id: 137, number: 100}
      assert block.chain == :polygon
      assert block.hash == nil
      assert block.size == nil
    end
  end

  describe "Transaction" do
    test "creates a transaction struct with all fields" do
      tx = %Transaction{
        chain: :ethereum,
        chain_id: 1,
        hash: "0xtx",
        block_number: 18_000_000,
        from: "0xsender",
        to: "0xreceiver",
        value: "1000000000000000000",
        value_decimal: 1.0,
        gas: 21_000,
        gas_price: 20_000_000_000,
        status: :success
      }

      assert tx.chain == :ethereum
      assert tx.status == :success
      assert tx.value_decimal == 1.0
    end

    test "has sensible defaults" do
      tx = %Transaction{chain: :bsc, chain_id: 56, hash: "0x"}
      assert tx.status == :pending
      assert tx.value_decimal == 0.0
    end
  end

  describe "Event" do
    test "creates an event struct with all fields" do
      event = %Event{
        chain: :ethereum,
        chain_id: 1,
        address: "0xcontract",
        topics: ["0xtopic0", "0xtopic1"],
        data: "0xdata",
        block_number: 18_000_000,
        transaction_hash: "0xtx",
        log_index: 5,
        event_name: "Transfer"
      }

      assert event.chain == :ethereum
      assert length(event.topics) == 2
      assert event.event_name == "Transfer"
    end

    test "has sensible defaults" do
      event = %Event{chain: :polygon, chain_id: 137}
      assert event.topics == []
      assert event.removed == false
    end
  end

  describe "TokenBalance" do
    test "creates a token balance struct" do
      balance = %TokenBalance{
        chain: :ethereum,
        chain_id: 1,
        address: "0xholder",
        contract_address: "0xtoken",
        token_name: "USD Coin",
        token_symbol: "USDC",
        token_decimals: 6,
        balance_raw: "1000000",
        balance_formatted: 1.0,
        token_type: :erc20
      }

      assert balance.token_symbol == "USDC"
      assert balance.token_type == :erc20
    end

    test "has sensible defaults" do
      balance = %TokenBalance{chain: :ethereum, chain_id: 1}
      assert balance.token_decimals == 18
      assert balance.balance_formatted == 0.0
      assert balance.token_type == :native
    end
  end

  describe "GasPrice" do
    test "creates a gas price struct" do
      gas = %GasPrice{
        chain: :ethereum,
        chain_id: 1,
        safe_gas_price: 20.0,
        propose_gas_price: 25.0,
        fast_gas_price: 35.0,
        base_fee: 18.0,
        timestamp: ~U[2023-09-01 00:00:00Z]
      }

      assert gas.unit == "gwei"
      assert gas.propose_gas_price == 25.0
    end

    test "has gwei as default unit" do
      gas = %GasPrice{chain: :ethereum, chain_id: 1}
      assert gas.unit == "gwei"
    end
  end
end
