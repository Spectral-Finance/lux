defmodule Lux.Web3.Gas.TransactionSimulatorTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Gas.TransactionSimulator

  describe "simulate/1" do
    test "simulates a basic transaction successfully" do
      tx = %{
        from: "0x1234567890abcdef1234567890abcdef12345678",
        to: "0xabcdef1234567890abcdef1234567890abcdef12",
        data: "0xa9059cbb0000",
        value: 0,
        network: "mainnet"
      }

      assert {:ok, result} = TransactionSimulator.simulate(tx)
      assert result.success == true
      assert result.reverted == false
      assert result.revert_reason == nil
      assert is_integer(result.estimated_gas)
      assert result.estimated_gas > 0
    end
  end

  describe "preflight_check/1" do
    test "passes for valid transaction" do
      tx = %{from: "0x1234567890abcdef1234567890abcdef12345678", to: "0xabcdef1234567890abcdef1234567890abcdef12", data: "0xa9059cbb", value: 0}
      assert {:ok, %{passed: true}} = TransactionSimulator.preflight_check(tx)
    end

    test "fails for missing from address" do
      assert {:error, msg} = TransactionSimulator.preflight_check(%{to: "0x1234", data: "0xabcd", value: 0})
      assert msg =~ "from"
    end

    test "fails for missing to address" do
      assert {:error, msg} = TransactionSimulator.preflight_check(%{from: "0x1234", data: "0xabcd", value: 0})
      assert msg =~ "to"
    end

    test "fails for invalid value" do
      assert {:error, msg} = TransactionSimulator.preflight_check(%{from: "0x1234", to: "0x5678", data: "0xab", value: -1})
      assert msg =~ "value"
    end

    test "fails for empty data" do
      assert {:error, msg} = TransactionSimulator.preflight_check(%{from: "0x1234", to: "0x5678", data: "0x", value: 0})
      assert msg =~ "data"
    end

    test "fails for missing data" do
      assert {:error, msg} = TransactionSimulator.preflight_check(%{from: "0x1234", to: "0x5678", value: 0})
      assert msg =~ "data"
    end
  end
end
