defmodule Lux.Web3.Wallet do
  @moduledoc """
  Wallet management for the Lux web3 infrastructure.

  A wallet wraps an EVM account together with the material needed to operate on
  it. Four wallet types are supported:

    * `:local` - an account backed by a locally held private key
    * `:hd` - an account derived through a hierarchical deterministic path (see
      `Lux.Web3.Wallet.HD`)
    * `:hardware` - a watch-only account controlled by a hardware device
    * `:multisig` - a watch-only account controlled by a multisig contract

  Only `:local` and `:hd` wallets can sign locally. Hardware and multisig
  wallets are created from an address and delegate signing to their external
  signer.

  ## Examples

      iex> {:ok, wallet} = Lux.Web3.Wallet.new()
      iex> String.starts_with?(wallet.address, "0x")
      true

      iex> Lux.Web3.Wallet.from_private_key("not-a-key")
      {:error, :invalid_private_key}
  """

  alias Ethers.Utils
  alias Lux.Web3.Chain

  @enforce_keys [:address, :type]
  defstruct [
    :address,
    :type,
    :public_key,
    :private_key,
    :derivation_path,
    :chain_id,
    meta: %{}
  ]

  @type wallet_type :: :local | :hd | :hardware | :multisig

  @type t :: %__MODULE__{
          address: String.t(),
          type: wallet_type(),
          public_key: binary() | nil,
          private_key: binary() | nil,
          derivation_path: String.t() | nil,
          chain_id: non_neg_integer() | nil,
          meta: map()
        }

  @wallet_types [:local, :hd, :hardware, :multisig]
  @signing_types [:local, :hd]

  @doc """
  Generates a fresh random `:local` wallet.
  """
  @spec new() :: {:ok, t()}
  def new, do: new([])

  @doc """
  Creates a wallet.

  ## Options

    * `:type` - one of `:local` (default), `:hd`, `:hardware`, `:multisig`
    * `:private_key` - private key as 32 raw bytes or hex string, used for local
      signing wallets. When omitted a random key is generated.
    * `:address` - required for watch-only (`:hardware` / `:multisig`) wallets
    * `:chain_id` - optional default chain id for the wallet
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, atom()}
  def new(opts) when is_list(opts) do
    type = Keyword.get(opts, :type, :local)

    with {:ok, type} <- validate_type(type),
         {:ok, chain} <- resolve_chain(Keyword.get(opts, :chain_id)) do
      build(type, chain, opts)
    end
  end

  def new(_opts), do: {:error, :invalid_options}

  @doc """
  Imports a wallet from a private key or a BIP-39 mnemonic phrase.

  A binary containing whitespace separated words with a valid mnemonic word
  count is treated as an HD mnemonic, everything else as a private key.
  """
  @spec import(term(), keyword()) :: {:ok, t()} | {:error, atom()}
  def import(nil, _opts), do: {:error, :missing_private_key}
  def import("", _opts), do: {:error, :missing_private_key}

  def import(input, opts) when is_binary(input) do
    if mnemonic?(input) do
      Lux.Web3.Wallet.HD.from_mnemonic(input, Keyword.put_new(opts, :type, :hd))
    else
      from_private_key(input, opts)
    end
  end

  def import(_input, _opts), do: {:error, :invalid_private_key}

  @doc """
  Builds a local signing wallet from a private key.
  """
  @spec from_private_key(term(), keyword()) :: {:ok, t()} | {:error, atom()}
  def from_private_key(private_key, opts \\ []) do
    type = Keyword.get(opts, :type, :local)

    with {:ok, type} <- validate_type(type),
         :ok <- ensure_signing_type(type),
         {:ok, key} <- normalize_private_key(private_key),
         {:ok, chain} <- resolve_chain(Keyword.get(opts, :chain_id)),
         {:ok, public_key} <- public_key_for(key) do
      {:ok,
       %__MODULE__{
         address: Utils.public_key_to_address(public_key),
         type: type,
         public_key: public_key,
         private_key: key,
         derivation_path: Keyword.get(opts, :path),
         chain_id: chain && chain.chain_id,
         meta: Keyword.get(opts, :meta, %{})
       }}
    end
  end

  @doc """
  Imports a watch-only wallet (`:hardware` or `:multisig`) from an address.
  """
  @spec import_address(term(), keyword()) :: {:ok, t()} | {:error, atom()}
  def import_address(address, opts \\ []) do
    type = Keyword.get(opts, :type, :hardware)

    with {:ok, type} <- validate_type(type),
         :ok <- ensure_watch_only_type(type),
         {:ok, address} <- normalize_address(address),
         {:ok, chain} <- resolve_chain(Keyword.get(opts, :chain_id)) do
      {:ok,
       %__MODULE__{
         address: address,
         type: type,
         chain_id: chain && chain.chain_id,
         meta: Keyword.get(opts, :meta, %{})
       }}
    end
  end

  @doc """
  Returns the checksummed address of a wallet.
  """
  @spec address(t()) :: String.t()
  def address(%__MODULE__{address: address}), do: address

  @doc """
  Returns `true` when the wallet can sign transactions locally.
  """
  @spec signing_wallet?(t()) :: boolean()
  def signing_wallet?(%__MODULE__{private_key: nil}), do: false
  def signing_wallet?(%__MODULE__{private_key: _key}), do: true

  @doc """
  Returns a copy of the wallet without the sensitive private key material.
  """
  @spec redact(t()) :: t()
  def redact(%__MODULE__{} = wallet), do: %{wallet | private_key: nil}

  @doc """
  Returns `true` when `address` is a well formed EVM address.
  """
  @spec valid_address?(term()) :: boolean()
  def valid_address?(address) when is_binary(address) do
    match?({:ok, _bin}, Utils.decode_address(String.trim(address)))
  end

  def valid_address?(_address), do: false

  @doc """
  Returns `true` when `private_key` is a usable 32-byte EVM private key.
  """
  @spec valid_private_key?(term()) :: boolean()
  def valid_private_key?(private_key) do
    match?({:ok, _key}, normalize_private_key(private_key))
  end

  @doc """
  Signs an `Ethers.Transaction` with the wallet's private key.

  Returns the hex encoded, signed raw transaction.
  """
  @spec sign_transaction(Ethers.Transaction.t(), t()) ::
          {:ok, binary()} | {:error, atom()}
  def sign_transaction(_transaction, %__MODULE__{private_key: nil}),
    do: {:error, :not_a_signing_wallet}

  def sign_transaction(transaction, %__MODULE__{private_key: key}) do
    Ethers.Signer.Local.sign_transaction(transaction, private_key: key)
  end

  def sign_transaction(_transaction, _wallet), do: {:error, :invalid_wallet}

  @doc """
  Normalizes a private key from raw bytes or hex form into 32 raw bytes.
  """
  @spec normalize_private_key(term()) ::
          {:ok, binary()} | {:error, :missing_private_key | :invalid_private_key}
  def normalize_private_key(nil), do: {:error, :missing_private_key}
  def normalize_private_key(""), do: {:error, :missing_private_key}

  def normalize_private_key("0x" <> hex) when byte_size(hex) == 64, do: decode_key(hex)
  def normalize_private_key("0X" <> hex) when byte_size(hex) == 64, do: decode_key(hex)

  def normalize_private_key(hex) when is_binary(hex) and byte_size(hex) == 64,
    do: decode_key(hex)

  def normalize_private_key(<<key::binary-size(32)>>), do: {:ok, key}
  def normalize_private_key(_private_key), do: {:error, :invalid_private_key}

  defp decode_key(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, <<key::binary-size(32)>>} -> {:ok, key}
      _other -> {:error, :invalid_private_key}
    end
  end

  defp build(type, chain, opts) when type in @signing_types do
    opts = Keyword.put(opts, :type, type)
    opts = Keyword.put(opts, :chain_id, chain && chain.chain_id)

    case normalize_private_key(Keyword.get(opts, :private_key)) do
      {:ok, _key} -> from_private_key(Keyword.get(opts, :private_key), opts)
      {:error, :missing_private_key} -> from_private_key(:crypto.strong_rand_bytes(32), opts)
      {:error, _reason} = error -> error
    end
  end

  defp build(type, chain, opts) do
    opts = Keyword.put(opts, :type, type)
    opts = Keyword.put(opts, :chain_id, chain && chain.chain_id)
    import_address(Keyword.get(opts, :address), opts)
  end

  defp resolve_chain(nil), do: {:ok, nil}

  defp resolve_chain(chain_id) do
    case Chain.get(chain_id) do
      {:ok, chain} -> {:ok, chain}
      {:error, _reason} = error -> error
    end
  end

  defp validate_type(type) when type in @wallet_types, do: {:ok, type}
  defp validate_type(_type), do: {:error, :unsupported_wallet_type}

  defp ensure_signing_type(type) when type in @signing_types, do: :ok
  defp ensure_signing_type(_type), do: {:error, :unsupported_wallet_type}

  defp ensure_watch_only_type(type) when type in [:hardware, :multisig], do: :ok
  defp ensure_watch_only_type(_type), do: {:error, :unsupported_wallet_type}

  defp normalize_address(nil), do: {:error, :missing_address}
  defp normalize_address(""), do: {:error, :missing_address}

  defp normalize_address(address) when is_binary(address) do
    case Utils.decode_address(String.trim(address)) do
      {:ok, decoded} -> {:ok, Utils.encode_address!(decoded)}
      {:error, _reason} -> {:error, :invalid_address}
    end
  end

  defp normalize_address(_address), do: {:error, :invalid_address}

  defp public_key_for(key) do
    case ExSecp256k1.create_public_key(key) do
      {:ok, public_key} -> {:ok, public_key}
      _error -> {:error, :invalid_private_key}
    end
  end

  defp mnemonic?(input) do
    input
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> then(&(length(&1) in [12, 15, 18, 21, 24]))
  end
end
