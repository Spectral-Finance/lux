defmodule Lux.Web3.Gas.TransactionReplacerTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Gas.TransactionReplacer

  describe "speed_up/2" do
    test "creates valid speed-up when fee is >= 110% of original" do
      original = %{hash: "0xabc123", nonce: 42, max_fee_per_gas: 30_000_000_000}
      new_fees = %{max_fee_per_gas: 35_000_000_000, max_priority_fee_per_gas: 2_000_000_000}

      assert {:ok, replacement} = TransactionReplacer.speed_up(original, new_fees)
      assert replacement.replacement_type == :speed_up
      assert replacement.new_nonce == 42
      assert replacement.new_max_fee_per_gas == 35_000_000_000
    end

    test "rejects speed-up when fee is less than 110% of original" do
      original = %{hash: "0xdef456", nonce: 10, max_fee_per_gas: 100_000_000_000}
      new_fees = %{max_fee_per_gas: 105_000_000_000, max_priority_fee_per_gas: 1_000_000_000}

      assert {:error, msg} = TransactionReplacer.speed_up(original, new_fees)
      assert msg =~ "at least 10%"
    end
  end

  describe "cancel/4" do
    test "creates valid cancel replacement" do
      assert {:ok, replacement} = TransactionReplacer.cancel("0xtx123", 42, 50_000_000_000, 2_000_000_000)
      assert replacement.replacement_type == :cancel
      assert replacement.new_nonce == 42
    end

    test "rejects zero gas price" do
      assert {:error, msg} = TransactionReplacer.cancel("0xtx123", 42, 0, 0)
      assert msg =~ "positive"
    end
  end

  describe "validate_replacement/2" do
    test "passes when replacement fee is >= 110% of original" do
      assert TransactionReplacer.validate_replacement(%{max_fee_per_gas: 100}, %{max_fee_per_gas: 110, max_priority_fee_per_gas: 5}) == :ok
    end

    test "fails when replacement fee is below 110%" do
      assert {:error, msg} = TransactionReplacer.validate_replacement(%{max_fee_per_gas: 100}, %{max_fee_per_gas: 109, max_priority_fee_per_gas: 5})
      assert msg =~ "below minimum"
    end

    test "fails when priority fee decreased" do
      assert {:error, msg} = TransactionReplacer.validate_replacement(
        %{max_fee_per_gas: 120, max_priority_fee_per_gas: 5},
        %{max_fee_per_gas: 130, max_priority_fee_per_gas: 3}
      )
      assert msg =~ "Priority fee"
    end
  end
end
