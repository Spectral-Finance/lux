defmodule Lux.Web3.Auth.TokenGateTest do
  use UnitCase, async: true

  alias Lux.Web3.Auth.TokenGate

  @contract "0x0000000000000000000000000000000000000abc"

  test "evaluates fungible and NFT token gates" do
    holdings = %{
      {1, @contract} => 100,
      {1, @contract, 42} => 1
    }

    rules = [
      %{chain_id: 1, contract: String.upcase(@contract), min_balance: 50},
      %{chain_id: 1, contract: @contract, token_id: 42, min_balance: 1}
    ]

    assert TokenGate.allowed?(holdings, rules)
    assert [%{allowed?: true}, %{allowed?: true}] = TokenGate.evaluate(holdings, rules)
  end

  test "rejects missing balances" do
    refute TokenGate.allowed?(%{}, [%{chain_id: 1, contract: @contract, min_balance: 1}])
  end
end
