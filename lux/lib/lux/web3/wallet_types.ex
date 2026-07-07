defmodule Lux.Web3.WalletTypes do
  @moduledoc """
  Defines wallet type specifications and behaviours for supporting multiple
  wallet types: local (generated/imported), HD (hierarchical deterministic),
  hardware, and multi-sig wallets.

  Each wallet type implements the `WalletProvider` behaviour, allowing the
  system to support heterogeneous wallet backends through a unified interface.
  """

  @type wallet_type :: :local | :hd | :hardware | :multisig
  @type chain_id :: pos_integer()
  @type address :: String.t()

  @type wallet_record :: %{
          address: address(),
          type: wallet_type(),
          chain_ids: [chain_id()],
          label: String.t() | nil,
          created_at: DateTime.t(),
          metadata: map()
        }

  @doc """
  Returns a new wallet record struct with the given fields.
  """
  @spec new(address(), wallet_type(), keyword()) :: wallet_record()
  def new(address, type, opts \\ []) do
    %{
      address: address,
      type: type,
      chain_ids: Keyword.get(opts, :chain_ids, [1]),
      label: Keyword.get(opts, :label),
      created_at: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Validates that the given wallet type is supported.
  Returns :ok for supported types and {:error, reason} for unsupported types
  with a clear message about what is not yet available.
  """
  @spec validate_type(wallet_type()) :: :ok | {:error, String.t()}
  def validate_type(:local), do: :ok

  def validate_type(:hd) do
    {:error,
     "HD wallet derivation (BIP-32/BIP-44) is not yet implemented. " <>
       "This requires adding a BIP-39 mnemonic generator and BIP-32 key derivation path support."}
  end

  def validate_type(:hardware) do
    {:error,
     "Hardware wallet support (Ledger, Trezor) is not yet implemented. " <>
       "This requires adding USB/HID transport layers and device-specific signing protocols."}
  end

  def validate_type(:multisig) do
    {:error,
     "Multi-signature wallet support is not yet implemented. " <>
       "This requires integration with Safe (Gnosis Safe) or similar on-chain multisig contracts."}
  end

  def validate_type(unknown) do
    {:error, "Unknown wallet type: #{inspect(unknown)}. Supported types: :local, :hd, :hardware, :multisig"}
  end

  @doc """
  Returns the list of all known wallet types.
  """
  @spec all_types() :: [wallet_type()]
  def all_types, do: [:local, :hd, :hardware, :multisig]

  @doc """
  Returns the list of currently implemented wallet types.
  """
  @spec implemented_types() :: [wallet_type()]
  def implemented_types, do: [:local]
end
