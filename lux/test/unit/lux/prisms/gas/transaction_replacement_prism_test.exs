defmodule Lux.Prisms.Gas.TransactionReplacementPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Gas.TransactionReplacementPrism

  describe "handler/2 - speed up" do
    test "validates action parameter" do
      result = TransactionReplacementPrism.handler(%{
        action: "speed_up",
        original_tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
      })

      assert {:error, reason} = result
      assert reason =~ "gas price"
    end

    test "rejects invalid action" do
      result = TransactionReplacementPrism.handler(%{
        action: "invalid",
        original_tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
      })

      assert {:error, reason} = result
      assert reason =~ "Invalid action"
    end

    test "enforces minimum 12% gas price increase" do
      result = TransactionReplacementPrism.handler(%{
        action: "speed_up",
        original_tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        new_gas_price_gwei: 32  # Only 6.6% increase, should fail
      })

      assert {:error, reason} = result
      assert reason =~ "12%"
    end

    test "accepts valid speed up with sufficient increase" do
      result = TransactionReplacementPrism.handler(%{
        action: "speed_up",
        original_tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        new_gas_price_gwei: 40,  # 33% increase, should pass
        new_priority_fee_gwei: 3.0
      })

      assert {:ok, result_data} = result
      assert result_data.action == "speed_up"
      assert result_data.status == "submitted"
      assert is_integer(result_data.nonce)
      assert result_data.gas_price_gwei == 40
    end

    test "requires original_tx_hash" do
      result = TransactionReplacementPrism.handler(%{
        action: "speed_up",
        new_gas_price_gwei: 40
      })

      assert {:error, reason} = result
      assert reason =~ "required"
    end
  end

  describe "handler/2 - cancel" do
    test "creates cancel transaction" do
      result = TransactionReplacementPrism.handler(%{
        action: "cancel",
        original_tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
      })

      assert {:ok, result_data} = result
      assert result_data.action == "cancel"
      assert result_data.status == "submitted"
      assert is_integer(result_data.nonce)
    end

    test "cancel uses 12% higher gas price" do
      result = TransactionReplacementPrism.handler(%{
        action: "cancel",
        original_tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
      })

      assert {:ok, result_data} = result
      # Original is 30 gwei, cancel should be 30 * 1.12 = 33.6
      assert result_data.gas_price_gwei >= 33.5
    end
  end
