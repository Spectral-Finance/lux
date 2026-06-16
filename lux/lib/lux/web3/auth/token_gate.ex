defmodule Lux.Web3.Auth.TokenGate do
  @moduledoc """
  Token-gating policy evaluator.

  The module is storage-agnostic. Callers provide a balance fetcher function so
  Lux can use Etherscan, an RPC client, cached balances, or a mocked test source.
  """

  @type gate_rule :: %{
          required(:chain_id) => integer(),
          required(:contract) => String.t(),
          required(:min_balance) => number()
        }

  @spec authorize(map(), [gate_rule()], function()) :: {:ok, :authorized} | {:error, String.t()}
  def authorize(%{address: address}, rules, balance_fetcher) when is_list(rules) and is_function(balance_fetcher, 3) do
    case Enum.find(rules, fn rule -> not passes_rule?(address, rule, balance_fetcher) end) do
      nil -> {:ok, :authorized}
      rule -> {:error, "Token gate failed for #{rule.contract} on chain #{rule.chain_id}"}
    end
  end

  def authorize(_, _, _), do: {:error, "Invalid token gate input"}

  defp passes_rule?(address, %{chain_id: chain_id, contract: contract, min_balance: min_balance}, balance_fetcher) do
    case balance_fetcher.(chain_id, contract, address) do
      {:ok, balance} when is_number(balance) -> balance >= min_balance
      balance when is_number(balance) -> balance >= min_balance
      _ -> false
    end
  end
end
