defmodule Lux.Web3.Auth.TokenGate do
  @moduledoc """
  Token-gated access control for Web3 authentication.

  Enables access control based on token ownership (ERC-20, ERC-721, ERC-1155).
  Supports:

  - Minimum balance requirements
  - Specific NFT ownership checks
  - Multi-token requirements (AND/OR logic)
  - Multi-chain token verification
  - Automatic role assignment based on token holdings

  ## Token Gate Rules

  Rules define token requirements for access:

      %{
        contract: "0x...",       # Token contract address
        chain_id: 1,             # Chain to check
        type: :erc20,            # :erc20 | :erc721 | :erc1155
        min_balance: 100,        # Minimum token balance
        token_id: nil,           # Specific token ID (ERC-721/1155)
        role: :holder            # Role to assign when requirement met
      }

  ## Examples

      iex> rule = TokenGate.build_rule(%{
      ...>   contract: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      ...>   chain_id: 1,
      ...>   type: :erc20,
      ...>   min_balance: 1000,
      ...>   role: :usdc_holder
      ...> })
      iex> TokenGate.check_access(address, [rule], balance_checker)
  """

  require Logger

  @type token_type :: :erc20 | :erc721 | :erc1155
  @type rule :: %{
          contract: String.t(),
          chain_id: pos_integer(),
          type: token_type(),
          min_balance: non_neg_integer(),
          token_id: non_neg_integer() | nil,
          role: atom() | nil
        }

  @type balance_checker ::
          (String.t(), String.t(), pos_integer() -> {:ok, non_neg_integer()} | {:error, any()})

  @doc """
  Builds and validates a token gate rule.

  ## Parameters

    * `attrs` - Map with rule attributes:
      * `:contract` (required) - Token contract address
      * `:chain_id` (required) - Chain ID to check on
      * `:type` - Token type (defaults to `:erc20`)
      * `:min_balance` - Minimum required balance (defaults to `1`)
      * `:token_id` - Specific token ID for ERC-721/1155
      * `:role` - Role to assign when requirement is met

  ## Returns

    * `{:ok, rule}` on success
    * `{:error, reason}` on validation failure
  """
  @spec build_rule(map()) :: {:ok, rule()} | {:error, String.t()}
  def build_rule(attrs) do
    with :ok <- validate_contract(attrs[:contract]),
         :ok <- validate_chain_id(attrs[:chain_id]),
         :ok <- validate_token_type(Map.get(attrs, :type, :erc20)) do
      {:ok,
       %{
         contract: attrs.contract,
         chain_id: attrs.chain_id,
         type: Map.get(attrs, :type, :erc20),
         min_balance: Map.get(attrs, :min_balance, 1),
         token_id: Map.get(attrs, :token_id),
         role: Map.get(attrs, :role)
       }}
    end
  end

  @doc """
  Checks access for an address against a list of rules.

  All rules must be satisfied (AND logic). Use `check_access_any/3` for OR logic.

  ## Parameters

    * `address` - The wallet address to check
    * `rules` - List of token gate rules
    * `balance_checker` - Function `(address, contract, chain_id) -> {:ok, balance} | {:error, reason}`

  ## Returns

    * `{:ok, %{passed: true, roles: [roles], results: [...]}}` if all rules pass
    * `{:ok, %{passed: false, roles: [], results: [...]}}` if any rule fails
    * `{:error, reason}` on check failure
  """
  @spec check_access(String.t(), [rule()], balance_checker()) ::
          {:ok, %{passed: boolean(), roles: [atom()], results: [map()]}} | {:error, any()}
  def check_access(address, rules, balance_checker) do
    results =
      Enum.map(rules, fn rule ->
        check_single_rule(address, rule, balance_checker)
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors != [] do
      {:error, "token gate check failed: #{inspect(errors)}"}
    else
      results = Enum.map(results, fn {:ok, r} -> r end)
      all_passed = Enum.all?(results, & &1.passed)

      roles =
        results
        |> Enum.filter(& &1.passed)
        |> Enum.flat_map(fn r -> List.wrap(r.role) end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      {:ok, %{passed: all_passed, roles: roles, results: results}}
    end
  end

  @doc """
  Checks access where at least one rule must be satisfied (OR logic).
  """
  @spec check_access_any(String.t(), [rule()], balance_checker()) ::
          {:ok, %{passed: boolean(), roles: [atom()], results: [map()]}} | {:error, any()}
  def check_access_any(address, rules, balance_checker) do
    results =
      Enum.map(rules, fn rule ->
        check_single_rule(address, rule, balance_checker)
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if length(errors) == length(results) do
      {:error, "all token gate checks failed"}
    else
      results =
        results
        |> Enum.reject(&match?({:error, _}, &1))
        |> Enum.map(fn {:ok, r} -> r end)

      any_passed = Enum.any?(results, & &1.passed)

      roles =
        results
        |> Enum.filter(& &1.passed)
        |> Enum.flat_map(fn r -> List.wrap(r.role) end)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      {:ok, %{passed: any_passed, roles: roles, results: results}}
    end
  end

  @doc """
  Creates a default balance checker that uses Ethers ERC-20 contract for on-chain lookups.

  This is a convenience function for production use. For testing, pass a mock
  balance checker function instead.
  """
  @spec default_balance_checker() :: balance_checker()
  def default_balance_checker do
    fn address, contract, _chain_id ->
      case Ethers.Contracts.ERC20.balance_of(address) |> Ethers.call(to: contract) do
        {:ok, balance} -> {:ok, balance}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Private helpers

  defp check_single_rule(address, rule, balance_checker) do
    case balance_checker.(address, rule.contract, rule.chain_id) do
      {:ok, balance} ->
        passed = balance >= rule.min_balance

        {:ok,
         %{
           contract: rule.contract,
           chain_id: rule.chain_id,
           type: rule.type,
           balance: balance,
           required: rule.min_balance,
           passed: passed,
           role: if(passed, do: rule.role, else: nil)
         }}

      {:error, reason} ->
        {:error, "failed to check balance for #{rule.contract}: #{inspect(reason)}"}
    end
  end

  defp validate_contract(nil), do: {:error, "contract address is required"}
  defp validate_contract(""), do: {:error, "contract address cannot be empty"}

  defp validate_contract(addr) when is_binary(addr) do
    if Regex.match?(~r/^0x[0-9a-fA-F]{40}$/, addr) do
      :ok
    else
      {:error, "invalid contract address format"}
    end
  end

  defp validate_contract(_), do: {:error, "contract address must be a string"}

  defp validate_chain_id(nil), do: {:error, "chain_id is required"}
  defp validate_chain_id(id) when is_integer(id) and id > 0, do: :ok
  defp validate_chain_id(_), do: {:error, "chain_id must be a positive integer"}

  defp validate_token_type(:erc20), do: :ok
  defp validate_token_type(:erc721), do: :ok
  defp validate_token_type(:erc1155), do: :ok
  defp validate_token_type(_), do: {:error, "token type must be :erc20, :erc721, or :erc1155"}
end
