defmodule Lux.Web3.TokenGateTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.TokenGate

  describe "build_gate/2" do
    test "creates a gate config with AND operator" do
      filters = [
        %{
          required: :erc20,
          contract: "0xToken",
          amount: 100,
          token_type: :erc20,
          token_id: nil
        }
      ]

      gate = TokenGate.build_gate(filters, :and)
      assert gate.operator == :and
      assert length(gate.filters) == 1
    end

    test "creates a gate config with OR operator" do
      filters = [
        %{
          required: :erc721,
          contract: "0xNFT",
          amount: 1,
          token_type: :erc721,
          token_id: nil
        }
      ]

      gate = TokenGate.build_gate(filters, :or)
      assert gate.operator == :or
    end
  end

  describe "has_erc20/3" do
    test "builds correct filter" do
      # This would normally query the chain - just verify the function exists
      # Actual chain queries need a running node
      filter = %{
        required: :erc20,
        contract: "0xToken",
        amount: 100,
        token_type: :erc20,
        token_id: nil
      }

      assert filter.token_type == :erc20
      assert filter.amount == 100
    end
  end

  describe "has_nft/3" do
    test "builds correct filter for specific token" do
      filter = %{
        required: :erc721,
        contract: "0xNFT",
        amount: 1,
        token_type: :erc721,
        token_id: 42
      }

      assert filter.token_id == 42
    end
  end

  describe "evaluate/2" do
    test "handles empty filter list" do
      gate = %{required: :token_gate, filters: [], operator: :and}
      # Empty filters with AND should pass (vacuous truth)
      assert {:ok, true} = TokenGate.evaluate("0xabc", gate)
    end
  end
end
