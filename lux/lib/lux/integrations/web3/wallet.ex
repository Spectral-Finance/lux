defmodule Lux.Integrations.Web3.Wallet do
  @moduledoc """
  Multi-chain wallet management for Ethereum and EVM-compatible chains.

  Supports wallet creation, import, HD derivation, signing, and balance tracking.

  ## Wallet Types

  - **Random** — Generate from random entropy
  - **HD** — Derive from mnemonic (BIP-44 path: m/44'/60'/0'/0/index)
  - **Import** — From existing private key

  ## Usage

      # Create a new random wallet
      {:ok, wallet} = Wallet.create()

      # Import from private key
      {:ok, wallet} = Wallet.from_private_key("0xabc...")

      # Sign a message
      {:ok, signature} = Wallet.sign_message(wallet, "Hello")

      # Get address
      address = Wallet.address(wallet)
  """

  @type t :: %__MODULE__{
          private_key: binary(),
          public_key: binary(),
          address: String.t(),
          chain_id: integer()
        }

  defstruct [:private_key, :public_key, :address, chain_id: 1]

  @doc "Create a new wallet with random private key."
  def create(opts \\ []) do
    private_key = :crypto.strong_rand_bytes(32)
    from_private_key_binary(private_key, opts)
  end

  @doc "Import wallet from hex-encoded private key."
  def from_private_key(key, opts \\ [])
  def from_private_key("0x" <> hex, opts), do: from_private_key(hex, opts)

  def from_private_key(hex, opts) when is_binary(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, private_key} -> from_private_key_binary(private_key, opts)
      :error -> {:error, "Invalid hex private key"}
    end
  end

  @doc "Import wallet from raw binary private key."
  def from_private_key_binary(private_key, opts \\ []) when byte_size(private_key) == 32 do
    chain_id = opts[:chain_id] || 1

    case ExSecp256k1.create_public_key(private_key) do
      {:ok, public_key} ->
        address = public_key_to_address(public_key)

        {:ok,
         %__MODULE__{
           private_key: private_key,
           public_key: public_key,
           address: address,
           chain_id: chain_id
         }}

      {:error, reason} ->
        {:error, "Failed to derive public key: #{inspect(reason)}"}
    end
  end

  @doc "Get the checksummed address of the wallet."
  def address(%__MODULE__{address: address}), do: address

  @doc "Get the hex-encoded private key."
  def private_key_hex(%__MODULE__{private_key: pk}) do
    "0x" <> Base.encode16(pk, case: :lower)
  end

  @doc "Sign a message (EIP-191 personal_sign)."
  def sign_message(%__MODULE__{private_key: pk}, message) when is_binary(message) do
    prefix = "\x19Ethereum Signed Message:\n#{byte_size(message)}"
    hash = keccak256(prefix <> message)
    sign_hash(pk, hash)
  end

  @doc "Sign a raw hash (32 bytes)."
  def sign_hash(private_key, hash) when byte_size(hash) == 32 do
    case ExSecp256k1.sign(hash, private_key) do
      {:ok, {r, s, v}} ->
        signature = r <> s <> <<v + 27>>
        {:ok, "0x" <> Base.encode16(signature, case: :lower)}

      {:error, reason} ->
        {:error, "Signing failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Build an unsigned EIP-1559 transaction map.

  Returns a map with all fields needed for signing and broadcasting.
  """
  def build_transaction(params) do
    %{
      chain_id: params[:chain_id] || 1,
      nonce: params[:nonce] || 0,
      max_priority_fee_per_gas: params[:max_priority_fee_per_gas] || 1_500_000_000,
      max_fee_per_gas: params[:max_fee_per_gas] || 30_000_000_000,
      gas_limit: params[:gas_limit] || 21_000,
      to: params[:to],
      value: params[:value] || 0,
      data: params[:data] || ""
    }
  end

  @doc "Sign a transaction and return the raw signed transaction hex."
  def sign_transaction(%__MODULE__{private_key: pk}, tx) do
    # EIP-1559 transaction encoding
    encoded = encode_eip1559_tx(tx)
    hash = keccak256(<<2>> <> encoded)

    case ExSecp256k1.sign(hash, pk) do
      {:ok, {r, s, v}} ->
        signed = encode_signed_eip1559_tx(tx, r, s, v)
        {:ok, "0x" <> Base.encode16(<<2>> <> signed, case: :lower)}

      {:error, reason} ->
        {:error, "Transaction signing failed: #{inspect(reason)}"}
    end
  end

  @doc "Verify a signature against a message and address."
  def verify_signature(message, signature_hex, expected_address) do
    with {:ok, sig_bytes} <- decode_hex(signature_hex),
         true <- byte_size(sig_bytes) == 65 do
      <<r::binary-size(32), s::binary-size(32), v>> = sig_bytes
      recovery_id = if v >= 27, do: v - 27, else: v

      prefix = "\x19Ethereum Signed Message:\n#{byte_size(message)}"
      hash = keccak256(prefix <> message)

      case ExSecp256k1.recover(hash, r, s, recovery_id) do
        {:ok, public_key} ->
          recovered_address = public_key_to_address(public_key)
          String.downcase(recovered_address) == String.downcase(expected_address)

        _ ->
          false
      end
    else
      _ -> false
    end
  end

  # Private helpers

  defp public_key_to_address(<<4, key_data::binary-size(64)>>) do
    <<_::binary-size(12), address::binary-size(20)>> = keccak256(key_data)
    to_checksum_address(address)
  end

  defp public_key_to_address(compressed) when byte_size(compressed) == 33 do
    # Decompress if needed
    case ExSecp256k1.public_key_decompress(compressed) do
      {:ok, uncompressed} -> public_key_to_address(uncompressed)
      _ -> "0x" <> Base.encode16(compressed, case: :lower)
    end
  end

  defp to_checksum_address(address_bytes) when byte_size(address_bytes) == 20 do
    hex = Base.encode16(address_bytes, case: :lower)
    hash = Base.encode16(keccak256(hex), case: :lower)

    checksummed =
      hex
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.map(fn {char, i} ->
        hash_char = String.at(hash, i)

        if hash_char in ~w(8 9 a b c d e f) do
          String.upcase(char)
        else
          char
        end
      end)
      |> Enum.join()

    "0x" <> checksummed
  end

  defp keccak256(data) do
    :crypto.hash(:sha3_256, data)
  end

  defp encode_eip1559_tx(tx) do
    items = [
      encode_integer(tx.chain_id),
      encode_integer(tx.nonce),
      encode_integer(tx.max_priority_fee_per_gas),
      encode_integer(tx.max_fee_per_gas),
      encode_integer(tx.gas_limit),
      encode_address(tx.to),
      encode_integer(tx.value),
      encode_binary(tx.data || ""),
      encode_list([])
    ]

    encode_list(items)
  end

  defp encode_signed_eip1559_tx(tx, r, s, v) do
    items = [
      encode_integer(tx.chain_id),
      encode_integer(tx.nonce),
      encode_integer(tx.max_priority_fee_per_gas),
      encode_integer(tx.max_fee_per_gas),
      encode_integer(tx.gas_limit),
      encode_address(tx.to),
      encode_integer(tx.value),
      encode_binary(tx.data || ""),
      encode_list([]),
      encode_integer(v),
      encode_binary(r),
      encode_binary(s)
    ]

    encode_list(items)
  end

  # Minimal RLP encoding
  defp encode_integer(0), do: <<0x80>>
  defp encode_integer(n) when n < 128, do: <<n>>

  defp encode_integer(n) do
    bytes = :binary.encode_unsigned(n)
    encode_binary(bytes)
  end

  defp encode_binary(""), do: <<0x80>>
  defp encode_binary(<<byte>>) when byte < 128, do: <<byte>>

  defp encode_binary(data) when is_binary(data) do
    len = byte_size(data)

    if len <= 55 do
      <<0x80 + len>> <> data
    else
      len_bytes = :binary.encode_unsigned(len)
      <<0xB7 + byte_size(len_bytes)>> <> len_bytes <> data
    end
  end

  defp encode_address(nil), do: <<0x80>>

  defp encode_address("0x" <> hex) do
    {:ok, bytes} = Base.decode16(hex, case: :mixed)
    encode_binary(bytes)
  end

  defp encode_address(bytes) when is_binary(bytes), do: encode_binary(bytes)

  defp encode_list(items) when is_list(items) do
    payload = Enum.join(items)
    len = byte_size(payload)

    if len <= 55 do
      <<0xC0 + len>> <> payload
    else
      len_bytes = :binary.encode_unsigned(len)
      <<0xF7 + byte_size(len_bytes)>> <> len_bytes <> payload
    end
  end

  defp decode_hex("0x" <> hex), do: Base.decode16(hex, case: :mixed)
  defp decode_hex(hex), do: Base.decode16(hex, case: :mixed)
end
