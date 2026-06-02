defmodule Lux.Web3.Auth.TokenGating.Test do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Web3.Auth.TokenGating

  describe "check_gate/3" do
    test "rejects unsupported token type" do
      gate = %{type: :invalid_type, contract_address: "0x0000000000000000000000000000000000000000"}
      result = TokenGating.check_gate("0x1234", gate)
      assert {:error, _} = result
    end

    test "rejects ERC1155 gate without token_id" do
      gate = %{type: :erc1155, contract_address: "0x0000000000000000000000000000000000000000"}
      result = TokenGating.check_gate("0x1234", gate)
      assert {:error, _} = result
    end
  end

  describe "check_gates_and/3" do
    test "returns false if any gate fails" do
      gates = [
        %{type: :invalid, contract_address: "0xdead000000000000000000000000000000000000"},
        %{type: :erc20, contract_address: "0x0000000000000000000000000000000000000000", min_balance: 1}
      ]

      result = TokenGating.check_gates_and("0x1234", gates)
      assert {:error, _} = result
    end
  end

  describe "check_gates_or/3" do
    test "returns false if all gates fail" do
      gates = [
        %{type: :invalid, contract_address: "0xdead000000000000000000000000000000000000"}
      ]

      result = TokenGating.check_gates_or("0x1234", gates)
      assert {:ok, false} = result
    end
  end

  describe "check_gates_threshold/3" do
    test "returns true when threshold is 0" do
      assert {:ok, true} = TokenGating.check_gates_threshold("0x1234", [], 0)
    end
  end
end
