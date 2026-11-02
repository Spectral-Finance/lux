defmodule Lux.Web3.Auth.TokenGating do
  @moduledoc """
  Token-Gated Access Control engine.
  Supports ERC-20 balance requirements, ERC-721 NFT ownership, ERC-1155 multi-token rules,
  and native token balance gates across multiple EVM chains with :all (AND), :any (OR),
  and :none (NOT) logical combinators.
  """

  @type rule_type :: :erc20 | :erc721 | :erc1155 | :native
  @type combinator :: :all | :any | :none

  @type rule :: %{
          type: rule_type(),
          contract: String.t() | nil,
          min_balance: non_neg_integer(),
          token_id: non_neg_integer() | nil,
          chain_id: pos_integer(),
          description: String.t() | nil
        }

  @type gate_spec :: %{
          operator: combinator(),
          rules: list(rule())
        }

  @doc """
  Builds an ERC-20 token balance rule.
  """
  @spec erc20_rule(String.t(), non_neg_integer(), pos_integer(), String.t() | nil) :: rule()
  def erc20_rule(contract, min_balance, chain_id \\ 1, desc \\ nil) do
    %{
      type: :erc20,
      contract: String.downcase(contract),
      min_balance: min_balance,
      token_id: nil,
      chain_id: chain_id,
      description: desc || "ERC20 #{contract} >= #{min_balance}"
    }
  end

  @doc """
  Builds an ERC-721 NFT ownership rule.
  """
  @spec erc721_rule(String.t(), pos_integer(), non_neg_integer() | nil, String.t() | nil) :: rule()
  def erc721_rule(contract, chain_id \\ 1, token_id \\ nil, desc \\ nil) do
    %{
      type: :erc721,
      contract: String.downcase(contract),
      min_balance: 1,
      token_id: token_id,
      chain_id: chain_id,
      description: desc || "ERC721 #{contract} NFT ownership"
    }
  end

  @doc """
  Builds an ERC-1155 multi-token rule.
  """
  @spec erc1155_rule(String.t(), non_neg_integer(), non_neg_integer(), pos_integer(), String.t() | nil) :: rule()
  def erc1155_rule(contract, token_id, min_balance \\ 1, chain_id \\ 1, desc \\ nil) do
    %{
      type: :erc1155,
      contract: String.downcase(contract),
      min_balance: min_balance,
      token_id: token_id,
      chain_id: chain_id,
      description: desc || "ERC1155 #{contract} ID:#{token_id} >= #{min_balance}"
    }
  end

  @doc """
  Builds a Native Coin balance rule (e.g. ETH, BNB, MATIC).
  """
  @spec native_rule(non_neg_integer(), pos_integer(), String.t() | nil) :: rule()
  def native_rule(min_balance, chain_id \\ 1, desc \\ nil) do
    %{
      type: :native,
      contract: nil,
      min_balance: min_balance,
      token_id: nil,
      chain_id: chain_id,
      description: desc || "Native coin balance >= #{min_balance}"
    }
  end

  @doc """
  Evaluates a token gate specification against a wallet address.
  Accepts a `balance_provider` which can be:
  - A function: `fn (rule, address) -> integer() end`
  - A map of balances: `%{contract_or_type => balance}`
  - nil: defaults to inspecting balances in gate_spec or returning 0
  """
  @spec evaluate_gate(String.t(), gate_spec() | rule() | list(rule()), term()) ::
          {:ok, map()} | {:error, :access_denied, map()}
  def evaluate_gate(address, gate_spec, balance_provider \\ nil)

  def evaluate_gate(address, %{operator: op, rules: rules}, provider) when is_list(rules) do
    clean_addr = String.downcase(address)
    results = Enum.map(rules, &eval_rule(&1, clean_addr, provider))

    matched = Enum.filter(results, & &1.passed)
    missing = Enum.reject(results, & &1.passed)

    passed =
      case op do
        :all -> length(missing) == 0
        :any -> length(matched) > 0
        :none -> length(matched) == 0
      end

    if passed do
      {:ok, %{allowed: true, operator: op, matched_rules: matched, address: clean_addr}}
    else
      {:error, :access_denied, %{allowed: false, operator: op, missing_rules: missing, address: clean_addr}}
    end
  end

  def evaluate_gate(address, rules, provider) when is_list(rules) do
    evaluate_gate(address, %{operator: :all, rules: rules}, provider)
  end

  def evaluate_gate(address, %{type: _} = single_rule, provider) do
    evaluate_gate(address, %{operator: :all, rules: [single_rule]}, provider)
  end

  # --- Internal rule evaluation ---

  defp eval_rule(rule, address, provider) do
    current_balance = fetch_balance(rule, address, provider)
    min = rule.min_balance || 1
    passed = current_balance >= min

    %{
      rule: rule,
      current_balance: current_balance,
      required_balance: min,
      passed: passed
    }
  end

  defp fetch_balance(rule, address, provider) when is_function(provider, 2) do
    provider.(rule, address)
  end

  defp fetch_balance(rule, address, provider) when is_function(provider, 1) do
    provider.(rule)
  end

  defp fetch_balance(rule, _address, balance_map) when is_map(balance_map) do
    key =
      case rule.type do
        :native -> :native
        _ -> rule.contract || :native
      end

    Map.get(balance_map, key) || Map.get(balance_map, to_string(key), 0)
  end

  defp fetch_balance(_rule, _address, _nil), do: 0
end
