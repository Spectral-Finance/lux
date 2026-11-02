defmodule Lux.Web3.WalletInfrastructure.MultiWalletRegistry do
  @moduledoc """
  Multi-wallet management registry supporting HD wallets, private key imports,
  Gnosis Safe multi-sig configurations, and hardware wallet stubs.
  """

  @type wallet_type :: :hd_wallet | :private_key | :multisig_contract | :hardware_device

  @type wallet_record :: %{
          address: String.t(),
          type: wallet_type(),
          label: String.t(),
          created_at: String.t(),
          metadata: map()
        }

  @doc """
  Registers a new wallet entry into the wallet registry.
  """
  @spec register_wallet(list(wallet_record()), wallet_type(), String.t(), String.t(), map()) ::
          {:ok, list(wallet_record()), wallet_record()} | {:error, String.t()}
  def register_wallet(registry, type, address, label, metadata \\ %{}) when is_list(registry) do
    normalized_addr = String.downcase(address)

    if Enum.any?(registry, &(String.downcase(&1.address) == normalized_addr)) do
      {:error, "Wallet with address #{address} already registered"}
    else
      record = %{
        address: address,
        type: type,
        label: label,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        metadata: metadata
      }

      {:ok, [record | registry], record}
    end
  end

  @doc """
  Finds a wallet by its checksummed or lowercased Ethereum address.
  """
  @spec find_by_address(list(wallet_record()), String.t()) :: {:ok, wallet_record()} | {:error, :not_found}
  def find_by_address(registry, address) when is_list(registry) do
    target = String.downcase(address)

    case Enum.find(registry, &(String.downcase(&1.address) == target)) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  @doc """
  Filters registered wallets by wallet type.
  """
  @spec list_by_type(list(wallet_record()), wallet_type()) :: list(wallet_record())
  def list_by_type(registry, type) when is_list(registry) do
    Enum.filter(registry, &(&1.type == type))
  end
end
