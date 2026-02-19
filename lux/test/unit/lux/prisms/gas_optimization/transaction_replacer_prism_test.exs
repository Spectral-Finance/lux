defmodule Lux.Prisms.GasOptimization.TransactionReplacerPrismTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.GasOptimization.TransactionReplacerPrism

  @valid_original_tx %{
    nonce: 42,
    to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18",
    value: "1000000000000000000",
    data: "0xa9059cbb",
    max_fee_per_gas_gwei: 20.0,
    max_priority_fee_per_gas_gwei: 2.0,
    gas_limit: 65_000
  }

  @valid_from "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  describe "handler/2 - speed_up action" do
    test "creates speed-up replacement with bumped fees" do
      input = %{
        action: "speed_up",
        original_tx: @valid_original_tx,
        from: @valid_from
      }

      assert {:ok, result} = TransactionReplacerPrism.handler(input, nil)

      assert result.action == "speed_up"
      assert result.replacement_tx.nonce == 42
      assert result.replacement_tx.from == @valid_from
      assert result.replacement_tx.to == @valid_original_tx.to
      assert result.replacement_tx.value == @valid_original_tx.value
      assert result.replacement_tx.max_fee_per_gas_gwei > @valid_original_tx.max_fee_per_gas_gwei
      assert result.replacement_tx.max_priority_fee_per_gas_gwei > @valid_original_tx.max_priority_fee_per_gas_gwei
      assert result.replacement_tx.type == "0x2"
    end

    test "bumps fees by at least 10%" do
      input = %{
        action: "speed_up",
        original_tx: @valid_original_tx,
        from: @valid_from,
        bump_percentage: 5.0  # Should be clamped to 10%
      }

      assert {:ok, result} = TransactionReplacerPrism.handler(input, nil)

      assert result.fee_increase_pct >= 10.0
      assert result.replacement_tx.max_fee_per_gas_gwei >= 20.0 * 1.10
    end

    test "supports custom bump percentage above minimum" do
      input = %{
        action: "speed_up",
        original_tx: @valid_original_tx,
        from: @valid_from,
        bump_percentage: 25.0
      }

      assert {:ok, result} = TransactionReplacerPrism.handler(input, nil)

      assert result.fee_increase_pct == 25.0
      assert result.replacement_tx.max_fee_per_gas_gwei >= 20.0 * 1.25
    end

    test "includes additional cost estimate" do
      input = %{
        action: "speed_up",
        original_tx: @valid_original_tx,
        from: @valid_from
      }

      assert {:ok, result} = TransactionReplacerPrism.handler(input, nil)

      assert is_number(result.estimated_additional_cost_gwei)
      assert result.estimated_additional_cost_gwei > 0
    end
  end

  describe "handler/2 - cancel action" do
    test "creates cancellation replacement" do
      input = %{
        action: "cancel",
        original_tx: @valid_original_tx,
        from: @valid_from
      }

      assert {:ok, result} = TransactionReplacerPrism.handler(input, nil)

      assert result.action == "cancel"
      assert result.replacement_tx.nonce == 42
      assert result.replacement_tx.to == @valid_from  # Self-transfer
      assert result.replacement_tx.value == "0"
      assert result.replacement_tx.data == "0x"
      assert result.replacement_tx.gas_limit == 21_000  # Minimal gas
      assert result.note =~ "cancel"
    end

    test "cancel bumps fees appropriately" do
      input = %{
        action: "cancel",
        original_tx: @valid_original_tx,
        from: @valid_from
      }

      assert {:ok, result} = TransactionReplacerPrism.handler(input, nil)

      assert result.replacement_tx.max_fee_per_gas_gwei > @valid_original_tx.max_fee_per_gas_gwei
    end
  end

  describe "handler/2 - replace action" do
    test "creates replacement with new data" do
      input = %{
        action: "replace",
        original_tx: @valid_original_tx,
        from: @valid_from,
        new_to: "0x1234567890123456789012345678901234567890",
        new_value: "2000000000000000000",
        new_data: "0xdeadbeef"
      }

      assert {:ok, result} = TransactionReplacerPrism.handler(input, nil)

      assert result.action == "replace"
      assert result.replacement_tx.nonce == 42
      assert result.replacement_tx.to == "0x1234567890123456789012345678901234567890"
      assert result.replacement_tx.value == "2000000000000000000"
      assert result.replacement_tx.data == "0xdeadbeef"
    end

    test "keeps original values when new ones not provided" do
      input = %{
        action: "replace",
        original_tx: @valid_original_tx,
        from: @valid_from
      }

      assert {:ok, result} = TransactionReplacerPrism.handler(input, nil)

      assert result.replacement_tx.to == @valid_original_tx.to
      assert result.replacement_tx.value == @valid_original_tx.value
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for unknown action" do
      input = %{
        action: "invalid",
        original_tx: @valid_original_tx,
        from: @valid_from
      }

      assert {:error, _} = TransactionReplacerPrism.handler(input, nil)
    end

    test "returns error when original_tx missing fee data" do
      input = %{
        action: "speed_up",
        original_tx: %{nonce: 1},
        from: @valid_from
      }

      assert {:error, msg} = TransactionReplacerPrism.handler(input, nil)
      assert msg =~ "max_fee_per_gas_gwei"
    end
  end

  describe "speed_up/3" do
    test "preserves original transaction data" do
      assert {:ok, result} = TransactionReplacerPrism.speed_up(@valid_original_tx, @valid_from, 15.0)

      assert result.replacement_tx.data == @valid_original_tx.data
      assert result.replacement_tx.gas_limit == @valid_original_tx.gas_limit
    end
  end

  describe "cancel/3" do
    test "sends zero value to self" do
      assert {:ok, result} = TransactionReplacerPrism.cancel(@valid_original_tx, @valid_from, 12.5)

      assert result.replacement_tx.to == @valid_from
      assert result.replacement_tx.value == "0"
    end
  end

  describe "view/0" do
    test "returns prism struct" do
      prism = TransactionReplacerPrism.view()

      assert prism.name == "Transaction Replacer"
      assert prism.description =~ "replacement"
    end
  end
end
