defmodule Lux.Web3.Auth.TokenGating do
  @moduledoc """
  Token-gated access control based on ERC20, ERC721, and ERC1155 token ownership.

  Provides configurable access rules based on token balances, NFT ownership,
  and multi-token requirements. Integrates with on-chain data via Ethers
  for real-time verification.
  """

  require Logger

  @typedoc "Token gate rule"
  @type gate_rule :: %{
          required(:type) => :erc20 | :erc721 | :erc1155,
          required(:contract_address) => String.t(),
          optional(:min_balance) => non_neg_integer(),
          optional(:token_id) => non_neg_integer(),
          optional(:chain_id) => non_neg_integer()
        }

  @typedoc "Token gate check result"
  @type gate_result :: {:ok, boolean()} | {:error, String.t()}

  @doc """
  Checks if an address passes a single token gate rule.

  Supports:
  - ERC20: Checks minimum balance
  - ERC721: Checks ownership of a specific token ID
  - ERC1155: Checks minimum balance of a specific token ID
  """
  @spec check_gate(String.t(), gate_rule(), keyword()) :: gate_result()
  def check_gate(address, gate, opts \\ []) do
    rpc_url = Keyword.get(opts, :rpc_url, rpc_url())

    case gate.type do
      :erc20 -> check_erc20(address, gate, rpc_url)
      :erc721 -> check_erc721(address, gate, rpc_url)
      :erc1155 -> check_erc1155(address, gate, rpc_url)
      _ -> {:error, "Unsupported token type: #{gate.type}"}
    end
  end

  @doc """
  Checks if an address passes all token gate rules (AND logic).
  """
  @spec check_gates_and(String.t(), [gate_rule()], keyword()) :: gate_result()
  def check_gates_and(address, gates, opts \\ []) do
    result =
      Enum.reduce_while(gates, {:ok, true}, fn gate, {:ok, _} ->
        case check_gate(address, gate, opts) do
          {:ok, true} -> {:cont, {:ok, true}}
          {:ok, false} -> {:halt, {:ok, false}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    result
  end

  @doc """
  Checks if an address passes any token gate rule (OR logic).
  """
  @spec check_gates_or(String.t(), [gate_rule()], keyword()) :: gate_result()
  def check_gates_or(address, gates, opts \\ []) do
    result =
      Enum.reduce_while(gates, {:ok, false}, fn gate, {:ok, _} ->
        case check_gate(address, gate, opts) do
          {:ok, true} -> {:halt, {:ok, true}}
          {:ok, false} -> {:cont, {:ok, false}}
          {:error, _} -> {:cont, {:ok, false}}
        end
      end)

    case result do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a composite gate that requires N of M gates to pass.
  """
  @spec check_gates_threshold(String.t(), [gate_rule()], non_neg_integer(), keyword()) ::
          gate_result()
  def check_gates_threshold(_address, _gates, threshold, _opts) when threshold < 1,
    do: {:ok, true}

  def check_gates_threshold(address, gates, threshold, opts \\ []) do
    results =
      Enum.map(gates, fn gate ->
        case check_gate(address, gate, opts) do
          {:ok, passed} -> passed
          _ -> false
        end
      end)

    passed_count = Enum.count(results, & &1)
    {:ok, passed_count >= threshold}
  end

  defp check_erc20(address, gate, rpc_url) do
    min_balance = Map.get(gate, :min_balance, 1)
    contract = String.downcase(gate.contract_address)

    with {:ok, balance} <- fetch_erc20_balance(address, contract, rpc_url) do
      {:ok, balance >= min_balance}
    end
  end

  defp check_erc721(address, gate, rpc_url) do
    contract = String.downcase(gate.contract_address)
    token_id = Map.get(gate, :token_id)

    with {:ok, owner} <- fetch_erc721_owner(contract, token_id, rpc_url) do
      {:ok, String.downcase(owner) == String.downcase(address)}
    end
  end

  defp check_erc1155(address, gate, rpc_url) do
    min_balance = Map.get(gate, :min_balance, 1)
    contract = String.downcase(gate.contract_address)
    token_id = Map.get(gate, :token_id)

    if is_nil(token_id) do
      {:error, "token_id required for ERC1155"}
    else
      with {:ok, balance} <- fetch_erc1155_balance(address, contract, token_id, rpc_url) do
        {:ok, balance >= min_balance}
      end
    end
  end

  defp fetch_erc20_balance(address, contract, rpc_url) do
    data = "0x70a08231" <> pad_address(address)

    case call_rpc(rpc_url, contract, data) do
      {:ok, result} -> {:ok, hex_to_int(result)}
      error -> error
    end
  end

  defp fetch_erc721_owner(contract, token_id, rpc_url) do
    data = "0x6352211e" <> pad_uint256(token_id)

    case call_rpc(rpc_url, contract, data) do
      {:ok, result} -> {:ok, "0x" <> String.slice(result, 26, 40)}
      error -> error
    end
  end

  defp fetch_erc1155_balance(address, contract, token_id, rpc_url) do
    data = "0x00fdd58e" <> pad_address(address) <> pad_uint256(token_id)

    case call_rpc(rpc_url, contract, data) do
      {:ok, result} -> {:ok, hex_to_int(result)}
      error -> error
    end
  end

  defp call_rpc(rpc_url, contract, data) do
    payload = %{
      jsonrpc: "2.0",
      id: System.unique_integer([:positive]),
      method: "eth_call",
      params: [
        %{to: contract, data: data},
        "latest"
      ]
    }

    case Req.post(rpc_url, json: payload, max_retries: 2) do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        {:ok, result}

      {:ok, %{status: 200, body: %{"error" => error}}} ->
        {:error, error["message"] || "RPC error"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp pad_address(address) do
    addr = String.trim_leading(address, "0x")
    String.pad_leading(addr, 64, "0")
  end

  defp pad_uint256(num) do
    Integer.to_string(num, 16) |> String.pad_leading(64, "0")
  end

  defp hex_to_int("0x" <> hex) do
    {int, _} = Integer.parse(hex, 16)
    int
  end

  defp rpc_url do
    Application.get_env(:ethers, :default_signer_opts, [])
    |> Keyword.get(:rpc_url)
  end
end
