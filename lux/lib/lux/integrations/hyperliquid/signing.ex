defmodule Lux.Integrations.Hyperliquid.Signing do
  @moduledoc """
  EIP-712 compatible signing for Hyperliquid L1 actions.

  Handles signature generation for order placement, cancellation,
  margin modifications, and deposits/withdrawals.

  Uses ExSecp256k1 for ECDSA signing and Lux.Native for keccak256 hashing.
  """

  alias Lux.Native

  @typedoc "EIP-712 style signature components"
  @type signature :: %{
    r: String.t(),
    s: String.t(),
    v: non_neg_integer()
  }

  @doc """
  Signs an L1 action payload.

  The action payload is serialized to JSON, hashed with keccak256,
  and signed with the private key.

  ## Parameters

    * `private_key` - Ethereum private key (hex string with or without 0x prefix)
    * `action_payload` - The action object to sign
    * `nonce` - Monotonically increasing timestamp in milliseconds

  ## Returns

    * `{:ok, signature}` - The ECDSA signature
    * `{:error, reason}` - Signing failure
  """
  @spec sign_l1_action(String.t(), map(), integer()) :: {:ok, signature()} | {:error, String.t()}
  def sign_l1_action(private_key, action_payload, nonce) do
    message = construct_message(action_payload, nonce)

    sign_hash(private_key, message)
  end

  @doc """
  Signs a USD deposit action.

  ## Parameters

    * `private_key` - Ethereum private key
    * `destination_address` - Destination wallet address
    * `usd_amount` - USD amount to deposit
    * `nonce` - Monotonically increasing nonce
  """
  @spec sign_usd_deposit(String.t(), String.t(), String.t(), integer()) ::
          {:ok, signature()} | {:error, String.t()}
  def sign_usd_deposit(private_key, destination_address, usd_amount, nonce) do
    action = %{
      "type" => "usdSend",
      "hyperliquidChain" => "Arbitrum",
      "destination" => destination_address,
      "amount" => usd_amount,
      "time" => nonce
    }

    sign_l1_action(private_key, action, nonce)
  end

  @doc """
  Signs a bank withdrawal action.

  ## Parameters

    * `private_key` - Ethereum private key
    * `destination_address` - Destination wallet address
    * `usd_amount` - USD amount to withdraw
    * `nonce` - Monotonically increasing nonce
  """
  @spec sign_bank_withdrawal(String.t(), String.t(), String.t(), integer()) ::
          {:ok, signature()} | {:error, String.t()}
  def sign_bank_withdrawal(private_key, destination_address, usd_amount, nonce) do
    action = %{
      "type" => "withdraw",
      "hyperliquidChain" => "Arbitrum",
      "destination" => destination_address,
      "amount" => usd_amount,
      "time" => nonce
    }

    sign_l1_action(private_key, action, nonce)
  end

  @doc """
  Signs an agent (delegated) L1 action.

  ## Parameters

    * `private_key` - Agent's Ethereum private key
    * `agent_address` - Agent's Ethereum address
    * `action_payload` - The action object
    * `nonce` - Monotonically increasing nonce
  """
  @spec sign_agent_l1_action(String.t(), String.t(), map(), integer()) ::
          {:ok, signature()} | {:error, String.t()}
  def sign_agent_l1_action(private_key, agent_address, action_payload, nonce) do
    message = %{
      "hyperliquidChain" => "Arbitrum",
      "agent" => agent_address,
      "action" => action_payload,
      "nonce" => nonce
    }

    sign_hash(private_key, message)
  end

  @doc """
  Generates the current timestamp in milliseconds for use as nonce.
  """
  @spec generate_nonce() :: integer()
  def generate_nonce do
    System.system_time(:millisecond)
  end

  @doc """
  Computes the keccak256 hash of the action payload for signing.

  Serializes the action message according to Hyperliquid's
  wire format and returns its keccak256 hash as a hex string.
  """
  @spec action_hash(map()) :: String.t()
  def action_hash(action_payload) do
    json = Jason.encode!(action_payload)

    if Native.loaded?() do
      Native.hash_keccak256(json)
    else
      :crypto.hash(:sha3_256, json) |> Base.encode16(case: :lower)
    end
  end

  defp construct_message(action_payload, nonce) do
    %{
      "hyperliquidChain" => "Arbitrum",
      "action" => action_payload,
      "nonce" => nonce
    }
  end

  defp sign_hash(private_key, message) do
    with {:ok, hash} <- hash_message(message),
         {:ok, key_binary} <- decode_key(private_key),
         {:ok, {r_binary, s_binary, recovery_id}} <- ExSecp256k1.sign(hash, key_binary) do
      signature = %{
        r: r_binary |> Base.encode16(case: :lower),
        s: s_binary |> Base.encode16(case: :lower),
        v: recovery_id + 27
      }

      {:ok, signature}
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    e in RuntimeError -> {:error, "Signing error: #{Exception.message(e)}"}
  end

  defp hash_message(message) do
    json = Jason.encode!(message)

    hex_hash = if Native.loaded?() do
      Native.hash_keccak256(json)
    else
      :crypto.hash(:sha3_256, json) |> Base.encode16(case: :lower)
    end

    case Base.decode16(hex_hash, case: :mixed) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, "Failed to decode hash hex"}
    end
  end

  defp decode_key("0x" <> hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, binary} when byte_size(binary) == 32 -> {:ok, binary}
      {:ok, _} -> {:error, "Invalid private key length"}
      :error -> {:error, "Invalid hex private key"}
    end
  end

  defp decode_key(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, binary} when byte_size(binary) == 32 -> {:ok, binary}
      {:ok, _} -> {:error, "Invalid private key length"}
      :error -> {:error, "Invalid hex private key"}
    end
  end
end
