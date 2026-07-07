defmodule Lux.Web3.Wallet do
  @moduledoc """
  Handles non-custodial wallet generation, address derivation, and multi-type
  wallet record management. Supports local (generated/imported) wallets with
  typed boundaries for HD, hardware, and multi-sig wallet expansion.
  """

  alias Lux.Web3.WalletTypes

  @type private_key :: String.t()
  @type address :: String.t()

  @doc """
  Generates a new random private key and its derived Ethereum address.
  Optionally accepts a wallet type (defaults to :local) and chain IDs.
  """
  @spec generate_wallet(keyword()) :: {:ok, %{private_key: private_key(), address: address(), wallet_record: map()}} | {:error, any()}
  def generate_wallet(opts \\ []) do
    wallet_type = Keyword.get(opts, :type, :local)
    chain_ids = Keyword.get(opts, :chain_ids, [1])
    label = Keyword.get(opts, :label)

    case WalletTypes.validate_type(wallet_type) do
      :ok ->
        do_generate_wallet(wallet_type, chain_ids, label)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_generate_wallet(:local, chain_ids, label) do
    private_key_bytes = :crypto.strong_rand_bytes(32)
    case derive_address(private_key_bytes) do
      {:ok, address} ->
        private_key_hex = "0x" <> Base.encode16(private_key_bytes, case: :lower)
        wallet_record = WalletTypes.new(address, :local, chain_ids: chain_ids, label: label)
        {:ok, %{private_key: private_key_hex, address: address, wallet_record: wallet_record}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Derives the Ethereum address for a given private key (binary or 0x-prefixed hex string).
  """
  @spec derive_address(binary() | private_key()) :: {:ok, address()} | {:error, any()}
  def derive_address("0x" <> hex_key) do
    case Base.decode16(hex_key, case: :mixed) do
      {:ok, binary_key} -> derive_address(binary_key)
      :error -> {:error, "Invalid hex-encoded private key"}
    end
  end

  def derive_address(binary_key) when is_binary(binary_key) and byte_size(binary_key) == 32 do
    case ExSecp256k1.create_public_key(binary_key) do
      {:ok, <<4, raw_pubkey::binary-size(64)>>} ->
        hashed = ExKeccak.hash_256(raw_pubkey)
        <<_::binary-size(12), raw_address::binary-size(20)>> = hashed
        
        address = "0x" <> Base.encode16(raw_address, case: :lower)
        checksummed =
          if Code.ensure_loaded?(Ethers.Utils) and function_exported?(Ethers.Utils, :to_checksum_address, 1) do
            Ethers.Utils.to_checksum_address(address)
          else
            checksum_address(address)
          end

        {:ok, checksummed}

      {:ok, _other} ->
        {:error, "Derived public key was not in uncompressed 65-byte format"}

      _error ->
        {:error, "Failed to derive public key"}
    end
  end

  def derive_address(_invalid), do: {:error, "Private key must be 32 bytes"}

  @doc """
  Checks if the given string is a valid Ethereum address.
  """
  @spec valid_address?(String.t()) :: boolean()
  def valid_address?("0x" <> hex_address) do
    String.length(hex_address) == 40 and match?({:ok, _}, Base.decode16(hex_address, case: :mixed))
  end

  def valid_address?(_), do: false

  @doc """
  Checksums an address according to EIP-55.
  """
  @spec checksum_address(String.t()) :: address()
  def checksum_address(address) do
    raw = String.replace(address, "0x", "") |> String.downcase()
    hash = ExKeccak.hash_256(raw) |> Base.encode16(case: :lower)
    
    checksummed =
      raw
      |> String.graphemes()
      |> Stream.zip(String.graphemes(hash))
      |> Enum.map(fn {char, hash_char} ->
        if hash_char >= "8" do
          String.upcase(char)
        else
          char
        end
      end)
      |> Enum.join("")

    "0x" <> checksummed
  end
end
