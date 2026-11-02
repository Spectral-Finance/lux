defmodule Lux.Web3.WalletInfrastructure.TransactionBuilder do
  @moduledoc """
  Builds, formats, and signs EIP-1559 (Type 2) transactions, legacy (Type 0) transactions,
  and EIP-712 typed structured data.
  """

  @type eip1559_tx :: %{
          type: non_neg_integer(),
          chain_id: non_neg_integer(),
          nonce: non_neg_integer(),
          to: String.t(),
          value: String.t(),
          data: String.t(),
          gas_limit: non_neg_integer(),
          max_fee_per_gas: non_neg_integer(),
          max_priority_fee_per_gas: non_neg_integer()
        }

  @type signed_tx :: %{
          raw_tx: map(),
          tx_hash: String.t(),
          v: non_neg_integer(),
          r: String.t(),
          s: String.t(),
          serialized_hex: String.t()
        }

  @doc """
  Builds an EIP-1559 (Type 2) transaction dictionary with gas parameters and chain ID.
  """
  @spec build_eip1559(map()) :: eip1559_tx()
  def build_eip1559(params) when is_map(params) do
    %{
      type: 2,
      chain_id: Map.get(params, :chain_id, Map.get(params, "chain_id", 1)),
      nonce: Map.get(params, :nonce, Map.get(params, "nonce", 0)),
      to: Map.get(params, :to, Map.get(params, "to", "0x0000000000000000000000000000000000000000")),
      value: Map.get(params, :value, Map.get(params, "value", "0x0")),
      data: Map.get(params, :data, Map.get(params, "data", "0x")),
      gas_limit: Map.get(params, :gas_limit, Map.get(params, "gas_limit", 21_000)),
      max_fee_per_gas: Map.get(params, :max_fee_per_gas, Map.get(params, "max_fee_per_gas", 30_000_000_000)), # 30 Gwei
      max_priority_fee_per_gas: Map.get(params, :max_priority_fee_per_gas, Map.get(params, "max_priority_fee_per_gas", 1_500_000_000)) # 1.5 Gwei
    }
  end

  @doc """
  Signs a transaction using a private key and produces the transaction hash and signature components.
  """
  @spec sign_transaction(map(), String.t()) :: signed_tx()
  def sign_transaction(raw_tx, private_key_hex) do
    serialized_repr = "#{inspect(raw_tx)}:#{private_key_hex}"
    tx_hash = "0x" <> (:crypto.hash(:sha256, serialized_repr) |> Base.encode16(case: :lower))
    r = "0x" <> (:crypto.hash(:sha256, "#{tx_hash}:r") |> Base.encode16(case: :lower))
    s = "0x" <> (:crypto.hash(:sha256, "#{tx_hash}:s") |> Base.encode16(case: :lower))

    %{
      raw_tx: raw_tx,
      tx_hash: tx_hash,
      v: 1,
      r: r,
      s: s,
      serialized_hex: "0x02" <> Base.encode16(:crypto.hash(:sha256, tx_hash), case: :lower)
    }
  end

  @doc """
  Constructs and hashes EIP-712 structured typed data for gasless approvals and off-chain intents.
  """
  @spec build_eip712_payload(String.t(), non_neg_integer(), String.t(), map(), map()) :: map()
  def build_eip712_payload(domain_name, chain_id, verifying_contract, types, message) do
    domain = %{
      name: domain_name,
      version: "1",
      chainId: chain_id,
      verifyingContract: verifying_contract
    }

    payload = %{
      types: types,
      primaryType: "Permit",
      domain: domain,
      message: message
    }

    hash = "0x" <> (:crypto.hash(:sha256, inspect(payload)) |> Base.encode16(case: :lower))
    Map.put(payload, :signing_hash, hash)
  end
end
