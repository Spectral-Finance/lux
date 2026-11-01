defmodule Lux.Web3.Gas.ReplacementManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Gas.ReplacementManager

  @valid_tx %{
    nonce: 42,
    from: "0x1111111111111111111111111111111111111111",
    to: "0x2222222222222222222222222222222222222222",
    value: 1_000_000_000,
    data: "0x",
    max_fee_per_gas: 30_000_000_000,
    max_priority_fee_per_gas: 2_000_000_000,
    chain_id: 1
  }

  describe "create_speed_up/2" do
    test "accelerates pending transaction and increases fees by at least 10%" do
      {:ok, speedup} = ReplacementManager.create_speed_up(@valid_tx, 1.20)

      assert speedup.nonce == 42
      assert speedup.to == @valid_tx.to
      assert speedup.max_fee_per_gas >= round(@valid_tx.max_fee_per_gas * 1.10)
      assert speedup.max_priority_fee_per_gas >= round(@valid_tx.max_priority_fee_per_gas * 1.10)
      assert speedup.action == :speed_up
    end

    test "fails if missing required fields" do
      invalid = %{nonce: 1}
      assert {:error, msg} = ReplacementManager.create_speed_up(invalid)
      assert String.contains?(msg, "Missing required")
    end
  end

  describe "create_cancel/2" do
    test "creates 0 ETH self-transfer to cancel stuck transaction" do
      {:ok, cancel} = ReplacementManager.create_cancel(@valid_tx, 1.25)

      assert cancel.nonce == 42
      assert cancel.to == @valid_tx.from
      assert cancel.value == 0
      assert cancel.data == "0x"
      assert cancel.max_fee_per_gas > @valid_tx.max_fee_per_gas
      assert cancel.action == :cancel
    end
  end

  describe "satisfies_rbf?/2" do
    test "checks 10% bump threshold correctly" do
      assert ReplacementManager.satisfies_rbf?(100, 110) == true
      assert ReplacementManager.satisfies_rbf?(100, 109) == false
      assert ReplacementManager.satisfies_rbf?(100, 120) == true
    end
  end
end
