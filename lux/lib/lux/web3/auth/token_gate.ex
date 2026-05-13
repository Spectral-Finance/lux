defmodule Lux.Web3.Auth.TokenGate do
  @moduledoc """
  Token-gated access rule evaluation.
  """

  @doc """
  Evaluates token-balance rules against normalized holdings.

  Holdings are keyed by `{chain_id, contract_address}` and values are raw token
  balances in the token's smallest unit.
  """
  @spec allowed?(map(), [map()]) :: boolean()
  def allowed?(holdings, rules) when is_list(rules) do
    Enum.all?(rules, fn rule ->
      key = {rule.chain_id, String.downcase(rule.contract)}
      balance = Map.get(holdings, key, 0)
      balance >= rule.min_balance
    end)
  end
end
