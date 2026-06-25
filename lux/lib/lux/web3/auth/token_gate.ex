defmodule Lux.Web3.Auth.TokenGate do
  @moduledoc """
  Token-gated access control.

  Determines whether an Ethereum address has access to a resource
  based on token/NFT holdings. Supports ERC-20, ERC-721, and ERC-1155 tokens.

  Uses the Ethers library to query on-chain token balances.
  """

  @type token_filter :: %{
          required: atom(),
          contract: String.t(),
          amount: non_neg_integer(),
          token_type: :erc20 | :erc721 | :erc1155,
          token_id: integer() | nil
        }

  @type gate_config :: %{
          required: atom(),
          filters: [token_filter()],
          operator: :and | :or
        }

  @doc """
  Evaluate a token gate for a given address.

  Returns {:ok, true} if access is granted, {:ok, false} if denied,
  or {:error, reason} on evaluation errors.
  """
  @spec evaluate(String.t(), gate_config()) :: {:ok, boolean()} | {:error, term()}
  def evaluate(address, gate_config) do
    filters = gate_config[:filters] || []
    operator = gate_config[:operator] || :and

    results =
      Enum.map(filters, fn filter ->
        check_token_holding(address, filter)
      end)

    passed = Enum.all?(results, fn
      {:ok, true} -> true
      _ -> false
    end)

    denied = Enum.any?(results, fn
      {:ok, false} -> true
      _ -> false
    end)

    case operator do
      :and ->
        # All filters must pass
        result = Enum.all?(results, fn {:ok, v} -> v end)
        {:ok, result}

      :or ->
        # At least one filter must pass
        result = Enum.any?(results, fn {:ok, v} -> v end)
        {:ok, result}
    end
  end

  @doc """
  Check if an address holds a specific ERC-20 token above a threshold.
  """
  @spec has_erc20(String.t(), String.t(), non_neg_integer()) :: {:ok, boolean()} | {:error, term()}
  def has_erc20(address, contract, minimum_amount) do
    filter = %{
      required: :erc20,
      contract: contract,
      amount: minimum_amount,
      token_type: :erc20,
      token_id: nil
    }

    evaluate_single(address, filter)
  end

  @doc """
  Check if an address owns a specific NFT (ERC-721).
  """
  @spec has_nft(String.t(), String.t(), integer()) :: {:ok, boolean()} | {:error, term()}
  def has_nft(address, contract, token_id) do
    filter = %{
      required: :erc721,
      contract: contract,
      amount: 1,
      token_type: :erc721,
      token_id: token_id
    }

    evaluate_single(address, filter)
  end

  @doc """
  Check if an address owns any NFT from a collection (ERC-721 balance > 0).
  """
  @spec has_nft_collection(String.t(), String.t()) :: {:ok, boolean()} | {:error, term()}
  def has_nft_collection(address, contract) do
    filter = %{
      required: :erc721,
      contract: contract,
      amount: 1,
      token_type: :erc721,
      token_id: nil
    }

    evaluate_single(address, filter)
  end

  @doc """
  Build a token gate configuration.
  """
  @spec build_gate([token_filter()], :and | :or) :: gate_config()
  def build_gate(filters, operator \ :and) do
    %{
      required: :token_gate,
      filters: filters,
      operator: operator
    }
  end

  # Internal helpers

  defp evaluate_single(address, filter) do
    case filter.token_type do
      :erc20 -> check_erc20(address, filter)
      :erc721 -> check_erc721(address, filter)
      :erc1155 -> check_erc1155(address, filter)
      _ -> {:error, :unknown_token_type}
    end
  end

  defp check_erc20(address, %{contract: contract, amount: min_amount}) do
    # Use ethers to call ERC-20 balanceOf
    abi = erc20_abi()
    call_result = Ethers.Contract.call(contract, abi, "balanceOf", [address], [])

    case call_result do
      {:ok, result} ->
        # Result is a tuple {_, balance}
        {_event, balance} = result
        {:ok, balance >= min_amount}

      {:error, reason} ->
        {:error, {:erc20_query_failed, reason}}
    end
  end

  defp check_erc721(address, %{contract: contract, token_id: token_id}) do
    abi = erc721_abi()

    case token_id do
      nil ->
        # Check balance > 0
        call_result = Ethers.Contract.call(contract, abi, "balanceOf", [address], [])
        case call_result do
          {:ok, {_event, balance}} -> {:ok, balance > 0}
          {:error, reason} -> {:error, {:erc721_query_failed, reason}}
        end

      tid ->
        # Check specific token ownership
        call_result = Ethers.Contract.call(contract, abi, "ownerOf", [tid], [])
        case call_result do
          {:ok, {_event, owner}} -> {:ok, String.downcase(owner) == String.downcase(address)}
          {:error, reason} -> {:error, {:erc721_query_failed, reason}}
        end
    end
  end

  defp check_erc1155(address, %{contract: contract, token_id: token_id, amount: min_amount}) do
    abi = erc1155_abi()
    call_result =
      Ethers.Contract.call(contract, abi, "balanceOf", [address, token_id || 0], [])

    case call_result do
      {:ok, {_event, balance}} -> {:ok, balance >= min_amount}
      {:error, reason} -> {:error, {:erc1155_query_failed, reason}}
    end
  end

  defp erc20_abi do
    [
      %{
        constant: true,
        inputs: [%{name: "account", type: "address"}],
        name: "balanceOf",
        outputs: [%{name: "", type: "uint256"}],
        type: "function"
      }
    ]
  end

  defp erc721_abi do
    [
      %{
        constant: true,
        inputs: [%{name: "owner", type: "address"}],
        name: "balanceOf",
        outputs: [%{name: "", type: "uint256"}],
        type: "function"
      },
      %{
        constant: true,
        inputs: [%{name: "tokenId", type: "uint256"}],
        name: "ownerOf",
        outputs: [%{name: "", type: "address"}],
        type: "function"
      }
    ]
  end

  defp erc1155_abi do
    [
      %{
        constant: true,
        inputs: [
          %{name: "account", type: "address"},
          %{name: "id", type: "uint256"}
        ],
        name: "balanceOf",
        outputs: [%{name: "", type: "uint256"}],
        type: "function"
      }
    ]
  end
end
