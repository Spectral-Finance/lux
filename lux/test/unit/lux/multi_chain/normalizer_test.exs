defmodule Lux.MultiChain.NormalizerTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Lux.MultiChain.DataModel.{Block, Event, GasPrice, TokenBalance, Transaction}
  alias Lux.MultiChain.Normalizer

  describe "normalize_block/3" do
    test "normalizes an Etherscan-style block response" do
      raw = %{
        "blockNumber" => "18000000",
        "blockHash" => "0xabc123",
        "parentHash" => "0xdef456",
        "timeStamp" => "1693500000",
        "blockMiner" => "0xminer123",
        "gasUsed" => "15000000",
        "gasLimit" => "30000000",
        "baseFeePerGas" => "20000000000",
        "txCount" => "150",
        "blockSize" => "50000"
      }

      block = Normalizer.normalize_block(raw, :ethereum, 1)

      assert %Block{} = block
      assert block.chain == :ethereum
      assert block.chain_id == 1
      assert block.number == 18_000_000
      assert block.hash == "0xabc123"
      assert block.parent_hash == "0xdef456"
      assert %DateTime{} = block.timestamp
      assert block.miner == "0xminer123"
      assert block.gas_used == 15_000_000
      assert block.gas_limit == 30_000_000
      assert block.base_fee_per_gas == 20_000_000_000
      assert block.transaction_count == 150
      assert block.size == 50_000
    end

    test "normalizes RPC-style block response with hex values" do
      raw = %{
        "number" => "0x112A880",
        "hash" => "0xblock_hash",
        "parentHash" => "0xparent_hash",
        "timestamp" => "0x64F5A4C0",
        "miner" => "0xminer_addr",
        "gasUsed" => "0xE4E1C0",
        "gasLimit" => "0x1C9C380",
        "transactionCount" => "0x96"
      }

      block = Normalizer.normalize_block(raw, :polygon, 137)

      assert block.chain == :polygon
      assert block.chain_id == 137
      assert block.number == 0x112A880
      assert block.gas_used == 0xE4E1C0
      assert block.gas_limit == 0x1C9C380
    end

    test "handles missing fields gracefully" do
      raw = %{"blockNumber" => "100"}
      block = Normalizer.normalize_block(raw, :bsc, 56)

      assert block.chain == :bsc
      assert block.number == 100
      assert block.hash == nil
      assert block.timestamp == nil
    end
  end

  describe "normalize_transaction/3" do
    test "normalizes an Etherscan transaction response" do
      raw = %{
        "hash" => "0xtx_hash",
        "blockNumber" => "18000000",
        "blockHash" => "0xblock_hash",
        "from" => "0xSender",
        "to" => "0xReceiver",
        "value" => "1000000000000000000",
        "gas" => "21000",
        "gasPrice" => "20000000000",
        "gasUsed" => "21000",
        "nonce" => "42",
        "input" => "0x",
        "txreceipt_status" => "1",
        "timeStamp" => "1693500000",
        "transactionIndex" => "5"
      }

      tx = Normalizer.normalize_transaction(raw, :ethereum, 1)

      assert %Transaction{} = tx
      assert tx.chain == :ethereum
      assert tx.chain_id == 1
      assert tx.hash == "0xtx_hash"
      assert tx.block_number == 18_000_000
      assert tx.from == "0xsender"
      assert tx.to == "0xreceiver"
      assert tx.value == "1000000000000000000"
      assert tx.value_decimal == 1.0
      assert tx.gas == 21_000
      assert tx.gas_price == 20_000_000_000
      assert tx.nonce == 42
      assert tx.status == :success
      assert %DateTime{} = tx.timestamp
    end

    test "normalizes transaction with failure status" do
      raw = %{
        "hash" => "0xfailed",
        "from" => "0xSender",
        "txreceipt_status" => "0",
        "value" => "0"
      }

      tx = Normalizer.normalize_transaction(raw, :polygon, 137)
      assert tx.status == :failure
    end

    test "normalizes transaction with pending status" do
      raw = %{
        "hash" => "0xpending",
        "from" => "0xSender",
        "value" => "0"
      }

      tx = Normalizer.normalize_transaction(raw, :bsc, 56)
      assert tx.status == :pending
    end

    test "handles nil to address (contract creation)" do
      raw = %{
        "hash" => "0xcreation",
        "from" => "0xCreator",
        "to" => nil,
        "value" => "0"
      }

      tx = Normalizer.normalize_transaction(raw, :ethereum, 1)
      assert tx.to == nil
    end
  end

  describe "normalize_event/3" do
    test "normalizes an event log response" do
      raw = %{
        "address" => "0xContractAddr",
        "topics" => [
          "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          "0x000000000000000000000000sender",
          "0x000000000000000000000000receiver"
        ],
        "data" => "0x000000000000000000000000000000000000000000000000000000003b9aca00",
        "blockNumber" => "18000000",
        "blockHash" => "0xblock_hash",
        "transactionHash" => "0xtx_hash",
        "transactionIndex" => "10",
        "logIndex" => "5",
        "removed" => false,
        "timeStamp" => "1693500000"
      }

      event = Normalizer.normalize_event(raw, :ethereum, 1)

      assert %Event{} = event
      assert event.chain == :ethereum
      assert event.chain_id == 1
      assert event.address == "0xcontractaddr"
      assert length(event.topics) == 3
      assert event.block_number == 18_000_000
      assert event.transaction_hash == "0xtx_hash"
      assert event.log_index == 5
      assert event.removed == false
    end

    test "handles removed events" do
      raw = %{
        "address" => "0xAddr",
        "removed" => true,
        "transactionHash" => "0xtx"
      }

      event = Normalizer.normalize_event(raw, :polygon, 137)
      assert event.removed == true
    end
  end

  describe "normalize_token_balance/4" do
    test "normalizes a native balance string" do
      balance =
        Normalizer.normalize_token_balance(
          "1000000000000000000",
          :ethereum,
          1,
          address: "0xaddr"
        )

      assert %TokenBalance{} = balance
      assert balance.chain == :ethereum
      assert balance.chain_id == 1
      assert balance.address == "0xaddr"
      assert balance.balance_raw == "1000000000000000000"
      assert balance.balance_formatted == 1.0
      assert balance.token_type == :native
      assert balance.token_symbol == "ETH"
    end

    test "normalizes a token balance map" do
      raw = %{
        "balance" => "5000000",
        "tokenName" => "USD Coin",
        "tokenSymbol" => "USDC",
        "tokenDecimal" => "6",
        "contractAddress" => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
      }

      balance = Normalizer.normalize_token_balance(raw, :ethereum, 1, address: "0xholder")

      assert balance.token_name == "USD Coin"
      assert balance.token_symbol == "USDC"
      assert balance.token_decimals == 6
      assert balance.balance_formatted == 5.0
      assert balance.contract_address == "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
      assert balance.token_type == :erc20
    end

    test "normalizes balance on different chains with correct currency" do
      matic = Normalizer.normalize_token_balance("1000000000000000000", :polygon, 137)
      assert matic.token_symbol == "MATIC"

      bnb = Normalizer.normalize_token_balance("1000000000000000000", :bsc, 56)
      assert bnb.token_symbol == "BNB"

      avax = Normalizer.normalize_token_balance("1000000000000000000", :avalanche, 43_114)
      assert avax.token_symbol == "AVAX"
    end
  end

  describe "normalize_gas_price/3" do
    test "normalizes gas oracle response" do
      raw = %{
        "SafeGasPrice" => "20.5",
        "ProposeGasPrice" => "25.0",
        "FastGasPrice" => "35.0",
        "suggestBaseFee" => "18.5"
      }

      gas = Normalizer.normalize_gas_price(raw, :ethereum, 1)

      assert %GasPrice{} = gas
      assert gas.chain == :ethereum
      assert gas.chain_id == 1
      assert gas.safe_gas_price == 20.5
      assert gas.propose_gas_price == 25.0
      assert gas.fast_gas_price == 35.0
      assert gas.base_fee == 18.5
      assert gas.unit == "gwei"
      assert %DateTime{} = gas.timestamp
    end

    test "handles missing base fee" do
      raw = %{
        "SafeGasPrice" => "3",
        "ProposeGasPrice" => "5",
        "FastGasPrice" => "7"
      }

      gas = Normalizer.normalize_gas_price(raw, :bsc, 56)
      assert gas.base_fee == nil
    end
  end

  describe "wei_to_decimal/2" do
    test "converts wei to ether (18 decimals)" do
      assert Normalizer.wei_to_decimal("1000000000000000000", 18) == 1.0
      assert Normalizer.wei_to_decimal("500000000000000000", 18) == 0.5
    end

    test "converts with different decimal places" do
      assert Normalizer.wei_to_decimal("1000000", 6) == 1.0
      assert Normalizer.wei_to_decimal("500000", 6) == 0.5
    end

    test "handles integer input" do
      assert Normalizer.wei_to_decimal(1_000_000_000_000_000_000, 18) == 1.0
    end

    test "handles hex strings" do
      assert Normalizer.wei_to_decimal("0xDE0B6B3A7640000", 18) == 1.0
    end

    test "handles zero" do
      assert Normalizer.wei_to_decimal("0", 18) == 0.0
    end

    test "handles invalid input" do
      assert Normalizer.wei_to_decimal("not_a_number", 18) == 0.0
    end
  end
end
