defmodule Lux.Web3.Auth.TokenGateTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Auth.TokenGate

  describe "allowed?/2" do
    test "requires all token-gate rules to pass" do
      holdings = %{
        {1, "0xusdc"} => 150_000_000,
        {137, "0xmembernft"} => 1
      }

      rules = [
        %{chain_id: 1, contract: "0xUSDC", min_balance: 100_000_000},
        %{chain_id: 137, contract: "0xMemberNFT", min_balance: 1}
      ]

      assert TokenGate.allowed?(holdings, rules)
      refute TokenGate.allowed?(holdings, [%{chain_id: 1, contract: "0xUSDC", min_balance: 200_000_000}])
    end
  end
end
