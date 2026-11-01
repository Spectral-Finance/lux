defmodule Lux.Web3.Gas.SimulatorTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Gas.Simulator

  describe "simulate_transaction/2" do
    test "simulates successful call and applies safety buffer" do
      tx = %{
        estimated_gas: 100_000,
        access_list: [
          %{storage_keys: ["0x01", "0x02"]}
        ],
        gas_token_burn: 2
      }

      result = Simulator.simulate_transaction(tx, safety_margin: 1.25)
      assert result.success == true
      assert result.recommended_gas_limit == 125_000
      assert result.access_list_savings == 400
      assert result.gas_refund > 0
      assert is_nil(result.revert_reason)
    end

    test "handles simulated revert" do
      tx = %{
        estimated_gas: 50_000,
        revert_data: "0x"
      }

      result = Simulator.simulate_transaction(tx)
      assert result.success == false
      assert String.contains?(result.revert_reason, "Execution reverted")
    end
  end

  describe "decode_revert_reason/1" do
    test "decodes standard Error(string) correctly" do
      # Error("Insufficient balance")
      # Selector: 08c379a0
      # Offset: 32 (0x20)
      # Length: 20 (0x14)
      # String: "Insufficient balance" (496e73756666696369656e742062616c616e6365)
      str = "Insufficient balance"
      hex_str = Base.encode16(str, case: :lower)
      padded_str = String.pad_trailing(hex_str, 64, "0")

      error_data =
        "0x08c379a0" <>
          String.pad_leading("20", 64, "0") <>
          String.pad_leading(Integer.to_string(byte_size(str), 16), 64, "0") <>
          padded_str

      assert Simulator.decode_revert_reason(error_data) == "Insufficient balance"
    end

    test "decodes Panic(uint256) codes" do
      # Panic(0x11) - Arithmetic overflow
      panic_data = "0x4e487b71" <> String.pad_leading("11", 64, "0")
      reason = Simulator.decode_revert_reason(panic_data)
      assert String.contains?(reason, "Arithmetic overflow")
    end

    test "identifies custom error selectors" do
      custom_data = "0xdeadbeef123456"
      assert Simulator.decode_revert_reason(custom_data) ==
               "Execution reverted with custom error selector: 0xdeadbeef"
    end
  end
end
