defmodule Lux.Web3.Wallet.HD do
  @moduledoc """
  Hierarchical deterministic (BIP-32) wallet derivation.

  Seeds are derived from BIP-39 mnemonics and child keys are derived with the
  BIP-32 private child key derivation function, so a single mnemonic can
  deterministically produce an unbounded tree of accounts.

  ## Examples

      iex> mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
      iex> {:ok, wallet} = Lux.Web3.Wallet.HD.from_mnemonic(mnemonic)
      iex> wallet.address
      "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
      iex> wallet.derivation_path
      "m/44'/60'/0'/0/0"

      iex> Lux.Web3.Wallet.HD.from_mnemonic("too short")
      {:error, :invalid_mnemonic_length}
  """

  alias Lux.Web3.Wallet

  # Order of the secp256k1 curve (n)
  @curve_order 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
  @hardened_offset 0x80000000
  @max_index 0x7FFFFFFF
  @default_path "m/44'/60'/0'/0/0"
  @word_counts [12, 15, 18, 21, 24]

  @type master :: %{private_key: binary(), chain_code: binary()}

  @doc """
  Returns the default BIP-44 derivation path for EVM accounts.
  """
  @spec default_path() :: String.t()
  def default_path, do: @default_path

  @doc """
  Derives the 64-byte BIP-39 seed from a mnemonic phrase.
  """
  @spec mnemonic_to_seed(String.t(), String.t()) :: binary()
  def mnemonic_to_seed(mnemonic, passphrase \\ "")
      when is_binary(mnemonic) and is_binary(passphrase) do
    :crypto.pbkdf2_hmac(:sha512, mnemonic, "mnemonic" <> passphrase, 2048, 64)
  end

  @doc """
  Validates a mnemonic phrase by word count.
  """
  @spec validate_mnemonic(term()) :: :ok | {:error, atom()}
  def validate_mnemonic(mnemonic) when is_binary(mnemonic) do
    words = mnemonic |> String.trim() |> String.split(~r/\s+/, trim: true)

    cond do
      words == [] -> {:error, :empty_mnemonic}
      length(words) not in @word_counts -> {:error, :invalid_mnemonic_length}
      true -> :ok
    end
  end

  def validate_mnemonic(_mnemonic), do: {:error, :invalid_mnemonic}

  @doc """
  Derives an HD wallet from a mnemonic phrase.
  """
  @spec from_mnemonic(term(), keyword()) :: {:ok, Wallet.t()} | {:error, atom()}
  def from_mnemonic(mnemonic, opts \\ []) do
    with :ok <- validate_mnemonic(mnemonic) do
      seed = mnemonic_to_seed(mnemonic, Keyword.get(opts, :passphrase, ""))
      from_seed(seed, Keyword.put(opts, :type, :hd))
    end
  end

  @doc """
  Derives an HD wallet from a raw seed at an absolute derivation path.
  """
  @spec from_seed(term(), keyword()) :: {:ok, Wallet.t()} | {:error, atom()}
  def from_seed(seed, opts \\ []) do
    path = Keyword.get(opts, :path, @default_path)

    with :ok <- validate_seed(seed),
         {:ok, master} <- master_from_seed(seed),
         {:ok, derived} <- derive_master(master, path) do
      Wallet.from_private_key(derived.private_key,
        type: :hd,
        path: path,
        chain_id: Keyword.get(opts, :chain_id),
        meta: %{seed: seed, chain_code: derived.chain_code}
      )
    end
  end

  @doc """
  Derives a sibling wallet from an HD wallet that carries its seed.
  """
  @spec derive(Wallet.t(), keyword()) :: {:ok, Wallet.t()} | {:error, atom()}
  def derive(%Wallet{meta: %{seed: seed}}, opts) when is_binary(seed) do
    from_seed(seed, Keyword.merge(opts, type: :hd))
  end

  def derive(%Wallet{}, _opts), do: {:error, :not_derivable}

  @doc """
  Builds the master key and chain code from a seed.
  """
  @spec master_from_seed(term()) :: {:ok, master()} | {:error, atom()}
  def master_from_seed(seed) when is_binary(seed) do
    <<il::binary-size(32), ir::binary-size(32)>> =
      :crypto.mac(:hmac, :sha512, "Bitcoin seed", seed)

    il_int = :binary.decode_unsigned(il)

    if il_int == 0 or il_int >= @curve_order do
      {:error, :invalid_seed}
    else
      {:ok, %{private_key: il, chain_code: ir}}
    end
  end

  def master_from_seed(_seed), do: {:error, :invalid_seed}

  @doc """
  Parses an absolute BIP-32 path into a list of hardened/normal child indexes.
  """
  @spec parse_path(term()) :: {:ok, [non_neg_integer()]} | {:error, :invalid_derivation_path}
  def parse_path(path) when is_binary(path) do
    case path |> String.trim() |> String.split("/", trim: true) do
      [root | segments] when root in ["m", "M"] -> build_path(segments)
      _other -> {:error, :invalid_derivation_path}
    end
  end

  def parse_path(_path), do: {:error, :invalid_derivation_path}

  defp derive_master(master, path) do
    with {:ok, indexes} <- parse_path(path) do
      Enum.reduce_while(indexes, {:ok, master}, fn index, {:ok, acc} ->
        case derive_child(acc, index) do
          {:ok, child} -> {:cont, {:ok, child}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)
    end
  end

  defp derive_child(%{private_key: key, chain_code: chain_code}, index) do
    with {:ok, data} <- child_data(key, index) do
      <<il::binary-size(32), ir::binary-size(32)>> =
        :crypto.mac(:hmac, :sha512, chain_code, data)

      case ExSecp256k1.private_key_tweak_add(key, il) do
        {:ok, child_key} -> {:ok, %{private_key: child_key, chain_code: ir}}
        _error -> {:error, :derivation_failed}
      end
    end
  end

  defp child_data(key, index) when index >= @hardened_offset do
    {:ok, <<0>> <> key <> <<index::32>>}
  end

  defp child_data(key, index) do
    with {:ok, public_key} <- ExSecp256k1.create_public_key(key),
         {:ok, compressed} <- ExSecp256k1.public_key_compress(public_key) do
      {:ok, compressed <> <<index::32>>}
    else
      _error -> {:error, :derivation_failed}
    end
  end

  defp build_path(segments) do
    result =
      Enum.reduce_while(segments, [], fn segment, acc ->
        case parse_segment(segment) do
          {:ok, index} -> {:cont, [index | acc]}
          {:error, _reason} = error -> {:halt, error}
        end
      end)

    case result do
      {:error, _reason} = error -> error
      indexes when is_list(indexes) -> {:ok, Enum.reverse(indexes)}
    end
  end

  defp parse_segment(segment) do
    {digits, hardened?} = strip_hardened(segment)

    case Integer.parse(digits) do
      {index, ""} when index >= 0 and index <= @max_index ->
        offset = if hardened?, do: @hardened_offset, else: 0
        {:ok, index + offset}

      _other ->
        {:error, :invalid_derivation_path}
    end
  end

  defp strip_hardened(segment) do
    cond do
      String.ends_with?(segment, "'") -> {String.trim_trailing(segment, "'"), true}
      String.ends_with?(segment, "h") -> {String.trim_trailing(segment, "h"), true}
      String.ends_with?(segment, "H") -> {String.trim_trailing(segment, "H"), true}
      true -> {segment, false}
    end
  end

  defp validate_seed(seed)
       when is_binary(seed) and byte_size(seed) >= 16 and byte_size(seed) <= 64,
       do: :ok

  defp validate_seed(_seed), do: {:error, :invalid_seed}
end
