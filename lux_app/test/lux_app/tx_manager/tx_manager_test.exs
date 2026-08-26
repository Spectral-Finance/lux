defmodule LuxApp.TxManagerTest do
  use ExUnit.Case

  alias LuxApp.TxManager
  alias LuxApp.TxManager.{GasOracle, ABIEncoder, GasToken, TxEncoder}

  test "EIP-1559 Optimization Strategies" do
    GasOracle.set_mock_base_fee(50_000_000_000)

    {:ok, economy} = TxManager.optimize_gas_fees(:economy)
    assert economy.max_priority_fee_per_gas == 1_000_000_000
    assert economy.max_fee_per_gas == 101_000_000_000

    {:ok, fast} = TxManager.optimize_gas_fees(:fast)
    assert fast.max_priority_fee_per_gas == 5_000_000_000
    assert fast.max_fee_per_gas == 105_000_000_000
  end

  test "Transaction Batching & Reporter Module (no UndefinedFunctionError)" do
    tx1 = %{to: "0x1111111111111111111111111111111111111111", data: "0xaabbccdd"}
    tx2 = %{to: "0x2222222222222222222222222222222222222222", data: "0x11223344"}

    batch = TxManager.batch_transactions([tx1, tx2])
    
    assert batch.to == "0xcA11bde05977b3631167028862bE2a173976CA11"
    assert String.starts_with?(batch.data, "0x82ad56cb") # Multicall3 aggregate3 selector
    assert batch.estimated_gas_saved == 21_000

    # Tests restored Reporter module
    report = TxManager.report_savings([tx1, tx2], batch)
    assert report.original_gas_cost == 42_000
    assert report.batched_gas_cost == 21_000
    assert report.gas_saved == 21_000

    empty_report = TxManager.report_savings([], batch)
    assert empty_report.gas_saved == 0
  end

  test "ABIEncoder exact zero-length bytes encoding" do
    assert ABIEncoder.pad_bytes_right("") == ""
    assert ABIEncoder.pad_bytes_right("0x") == ""
    assert ABIEncoder.pad_bytes_right("0xaabb") == "aabb000000000000000000000000000000000000000000000000000000000000"
  end

  test "TxEncoder generates canonical EIP-1559 RLP signed raw_tx" do
    tx = %{
      from: "0x000000000000000000000000000000000000000A",
      nonce: 5,
      max_fee_per_gas: 100_000_000_000,
      max_priority_fee_per_gas: 2_000_000_000
    }

    raw_tx = TxEncoder.encode_and_sign(tx)
    assert is_binary(raw_tx)
    assert String.starts_with?(raw_tx, "0x02") # EIP-1559 typed transaction prefix
    assert {:ok, %{type: :eip1559, valid_envelope: true}} = TxEncoder.decode_and_recover(raw_tx)
  end

  test "Transaction Replacement (Speed Up / Cancel) submits signed raw_tx" do
    tx = %{from: "0x000000000000000000000000000000000000000A", nonce: 5, max_fee_per_gas: 100_000_000_000, max_priority_fee_per_gas: 2_000_000_000}

    {:ok, _hash, speed_up_tx} = TxManager.speed_up(tx)
    assert speed_up_tx.max_fee_per_gas == 110_000_000_000
    assert speed_up_tx.max_priority_fee_per_gas == 2_200_000_000
    assert speed_up_tx.nonce == 5
    assert String.starts_with?(speed_up_tx.raw_tx, "0x02")

    {:ok, _hash, cancel_tx} = TxManager.cancel(tx)
    assert cancel_tx.to == "0x000000000000000000000000000000000000000A"
    assert cancel_tx.value == 0
    assert cancel_tx.max_fee_per_gas == 110_000_000_000
    assert cancel_tx.max_priority_fee_per_gas == 2_200_000_000
    assert String.starts_with?(cancel_tx.raw_tx, "0x02")
  end

  test "MEV Protection Wrappers via RPC" do
    tx = %{to: "0xB", value: 1000}

    {:ok, _hash, metadata} = TxManager.protect_transaction(tx, builder: "flashbots", slippage: 0.05)
    
    assert metadata.protection_enabled == true
    assert metadata.routing == :private
    assert metadata.builder == "flashbots"
    assert metadata.slippage_tolerance == 0.05
  end

  test "Gas Token Multicall3 aggregate3 / aggregate3Value bundles" do
    # Non-value call -> aggregate3 (0x82ad56cb)
    tx1 = %{from: "0x000000000000000000000000000000000000000A", to: "0x1111111111111111111111111111111111111111", data: "0x1234", value: 0}
    wrapped1 = GasToken.wrap_with_gas_token(tx1, "0x2222222222222222222222222222222222222222", 10)
    assert wrapped1.to == "0xcA11bde05977b3631167028862bE2a173976CA11"
    assert String.starts_with?(wrapped1.data, "0x82ad56cb")

    # Value-bearing call -> aggregate3Value (0x1048a435)
    tx2 = %{from: "0x000000000000000000000000000000000000000A", to: "0x1111111111111111111111111111111111111111", data: "0x1234", value: 1_000_000_000}
    wrapped2 = GasToken.wrap_with_gas_token(tx2, "0x2222222222222222222222222222222222222222", 10)
    assert wrapped2.to == "0xcA11bde05977b3631167028862bE2a173976CA11"
    assert wrapped2.value == 1_000_000_000
    assert String.starts_with?(wrapped2.data, "0x1048a435")
  end

  test "Production RPCAdapter configuration contract wiring" do
    assert Application.get_env(:lux_app, :rpc_adapter) != nil
  end
end
