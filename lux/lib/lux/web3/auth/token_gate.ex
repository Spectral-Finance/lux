defmodule Lux.Web3.Auth.TokenGate do
  @moduledoc """
  Token-gated access checks over normalized wallet holdings.
  """

  @doc """
  Returns true when every rule is satisfied by the provided holdings.

  Holdings may be keyed by `{chain_id, contract}` for fungible balances or by
  `{chain_id, contract, token_id}` for NFT-style ownership.
  """
  @spec allowed?(map(), [map()]) :: boolean()
  def allowed?(holdings, rules) when is_list(rules) do
    holdings |> evaluate(rules) |> Enum.all?(& &1.allowed?)
  end

  @doc """
  Evaluates each token gate rule with evidence.
  """
  @spec evaluate(map(), [map()]) :: [map()]
  def evaluate(holdings, rules) when is_list(rules) do
    Enum.map(rules, fn rule ->
      chain_id = value(rule, :chain_id)
      contract = value(rule, :contract) |> normalize_contract()
      token_id = value(rule, :token_id)
      min_balance = value(rule, :min_balance) || 1
      actual = balance_for(holdings, chain_id, contract, token_id)

      %{
        chain_id: chain_id,
        contract: contract,
        token_id: token_id,
        min_balance: min_balance,
        actual_balance: actual,
        allowed?: actual >= min_balance
      }
    end)
  end

  defp balance_for(holdings, chain_id, contract, nil) do
    Map.get(holdings, {chain_id, contract}) ||
      Map.get(holdings, contract) ||
      Map.get(holdings, {to_string(chain_id), contract}) ||
      0
  end

  defp balance_for(holdings, chain_id, contract, token_id) do
    Map.get(holdings, {chain_id, contract, token_id}) ||
      Map.get(holdings, {to_string(chain_id), contract, to_string(token_id)}) ||
      0
  end

  defp normalize_contract(nil), do: nil
  defp normalize_contract(contract), do: contract |> to_string() |> String.downcase()

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp value(_map, _key), do: nil
end
