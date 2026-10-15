defmodule Lux.Web3.Wallet do
  @moduledoc """
  Multi-wallet management system supporting standard keypair wallets, BIP-32/BIP-44
  HD wallets, hardware signer wallets, and M-of-N multi-signature wallets, with
  encrypted key storage and multi-chain balance monitoring.
  """

  alias Lux.UUID
  alias Lux.Web3.Chains
  alias Lux.Web3.Wallet.KeyManager

  @wallet_table :lux_web3_wallets
  @balance_table :lux_web3_balances
  @default_passphrase "lux-internal-vault-passphrase"

  @type wallet_type :: :standard | :hd | :hardware | :multisig

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t() | nil,
          type: wallet_type(),
          address: String.t(),
          derivation_path: String.t() | nil,
          accounts: [%{index: non_neg_integer(), path: String.t(), address: String.t()}],
          owners: [String.t()],
          threshold: pos_integer() | nil,
          hardware_signer: (binary(), map() -> {:ok, map()} | {:error, term()}) | nil,
          encrypted_secret: KeyManager.encrypted_envelope() | nil,
          chains: [atom()],
          metadata: map(),
          created_at: DateTime.t()
        }

  defstruct id: nil,
            name: nil,
            type: :standard,
            address: nil,
            derivation_path: nil,
            accounts: [],
            owners: [],
            threshold: nil,
            hardware_signer: nil,
            encrypted_secret: nil,
            chains: [:ethereum, :arbitrum, :optimism, :base, :polygon, :bsc],
            metadata: %{},
            created_at: nil

  @doc """
  Ensures ETS tables for wallets and balance snapshots are initialized.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    ensure_table(@wallet_table)
    ensure_table(@balance_table)
    :ok
  end

  @doc """
  Clears all stored wallets and balance snapshots.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@wallet_table)
    :ets.delete_all_objects(@balance_table)
    :ok
  end

  @doc """
  Creates a new wallet of the requested type (`:standard`, `:hd`, `:hardware`, or `:multisig`).
  """
  @spec create(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def create(opts \\ %{}) do
    ensure_started()
    params = Map.new(opts)
    type = Map.get(params, :type, :standard)

    case build_wallet(type, params) do
      {:ok, %__MODULE__{} = wallet} ->
        :ets.insert(@wallet_table, {wallet.id, wallet})
        {:ok, wallet}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Imports an existing wallet from a private key or mnemonic/seed phrase.
  """
  @spec import_wallet(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def import_wallet(opts) do
    params = Map.new(opts)

    cond do
      is_binary(params[:private_key]) ->
        create(Map.put(params, :type, :standard))

      is_binary(params[:mnemonic]) or is_binary(params[:seed]) ->
        create(Map.put(params, :type, :hd))

      true ->
        {:error, :missing_import_credentials}
    end
  end

  @doc """
  Retrieves a managed wallet by ID or checksummed address.
  """
  @spec get_wallet(String.t()) :: {:ok, t()} | {:error, :not_found}
  def get_wallet(id_or_address) when is_binary(id_or_address) do
    ensure_started()

    case :ets.lookup(@wallet_table, id_or_address) do
      [{^id_or_address, wallet}] ->
        {:ok, wallet}

      [] ->
        find_by_address(id_or_address)
    end
  end

  @doc """
  Lists all registered wallets.
  """
  @spec list_wallets() :: [t()]
  def list_wallets do
    ensure_started()

    @wallet_table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, wallet} -> wallet end)
  end

  @doc """
  Derives a new indexed child account for an `:hd` wallet along `"m/44'/60'/0'/0/{index}"`
  (or a custom path) and appends it to the wallet's account list.
  """
  @spec derive_account(String.t(), non_neg_integer(), keyword()) ::
          {:ok, %{index: non_neg_integer(), path: String.t(), address: String.t()}, t()}
          | {:error, term()}
  def derive_account(wallet_id, index, opts \\ [])
      when is_binary(wallet_id) and is_integer(index) and index >= 0 do
    passphrase = Keyword.get(opts, :passphrase, @default_passphrase)
    path = Keyword.get(opts, :path, "m/44'/60'/0'/0/#{index}")

    with {:ok, %__MODULE__{type: :hd, encrypted_secret: envelope} = wallet} <-
           get_wallet(wallet_id),
         {:ok, seed} <- KeyManager.decrypt_secret(envelope, passphrase),
         {:ok, derived} <- KeyManager.derive_hd_key(seed, path) do
      account = %{index: index, path: path, address: derived.address}
      accounts = Enum.uniq_by(wallet.accounts ++ [account], & &1.path)
      updated = %{wallet | accounts: accounts}
      :ets.insert(@wallet_table, {wallet.id, updated})
      {:ok, account, updated}
    else
      {:ok, %__MODULE__{}} -> {:error, :not_hd_wallet}
      error -> error
    end
  end

  @doc """
  Exports the decrypted private key for a `:standard` or `:hd` wallet.
  """
  @spec export_private_key(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def export_private_key(wallet_id, opts \\ []) do
    passphrase = Keyword.get(opts, :passphrase, @default_passphrase)
    path = Keyword.get(opts, :path)

    with {:ok, wallet} <- get_wallet(wallet_id) do
      extract_wallet_private_key(wallet, passphrase, path)
    end
  end

  @doc """
  Queries the native balance of a wallet on a specific EVM chain via JSON-RPC (`eth_getBalance`)
  and records a balance snapshot.
  """
  @spec get_balance(String.t(), atom() | pos_integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_balance(wallet_id_or_address, chain_ref \\ :ethereum, opts \\ []) do
    ensure_started()
    block_tag = Keyword.get(opts, :block, "latest")

    with {:ok, address} <- resolve_address(wallet_id_or_address),
         {:ok, chain} <- Chains.get_chain(chain_ref),
         {:ok, hex_balance} <-
           Chains.rpc_call(chain.id, "eth_getBalance", [address, block_tag], opts),
         {:ok, wei} <- Chains.hex_to_integer(hex_balance) do
      formatted = Float.round(wei / :math.pow(10, chain.decimals), 8)

      snapshot = %{
        address: address,
        chain: chain.id,
        chain_id: chain.chain_id,
        symbol: chain.native_symbol,
        balance_wei: wei,
        balance_formatted: formatted,
        block: block_tag,
        checked_at: DateTime.utc_now()
      }

      record_balance_snapshot(address, chain.id, snapshot)
      {:ok, snapshot}
    end
  end

  @doc """
  Queries native balances for a wallet across multiple EVM chains.
  """
  @spec get_multi_chain_balances(String.t(), [atom() | pos_integer()], keyword()) ::
          {:ok, %{balances: [map()], errors: map()}} | {:error, term()}
  def get_multi_chain_balances(
        wallet_id_or_address,
        chains \\ [:ethereum, :polygon, :arbitrum],
        opts \\ []
      ) do
    with {:ok, address} <- resolve_address(wallet_id_or_address) do
      {balances, errors} =
        Enum.reduce(chains, {[], %{}}, fn chain_ref, {ok_acc, err_acc} ->
          case get_balance(address, chain_ref, opts) do
            {:ok, snap} -> {[snap | ok_acc], err_acc}
            {:error, reason} -> {ok_acc, Map.put(err_acc, chain_ref, reason)}
          end
        end)

      {:ok, %{address: address, balances: Enum.reverse(balances), errors: errors}}
    end
  end

  @doc """
  Returns recorded balance history snapshots for a wallet address and optional chain filter.
  """
  @spec get_balance_history(String.t(), atom() | nil) :: [map()]
  def get_balance_history(wallet_id_or_address, chain_filter \\ nil) do
    ensure_started()

    case resolve_address(wallet_id_or_address) do
      {:ok, address} ->
        case :ets.lookup(@balance_table, address) do
          [{^address, history}] ->
            if is_nil(chain_filter) do
              history
            else
              Enum.filter(history, &(&1.chain == chain_filter))
            end

          [] ->
            []
        end

      _ ->
        []
    end
  end

  defp record_balance_snapshot(address, _chain, snapshot) do
    existing =
      case :ets.lookup(@balance_table, address) do
        [{^address, list}] -> list
        [] -> []
      end

    :ets.insert(@balance_table, {address, existing ++ [snapshot]})
  end

  defp resolve_address("0x" <> _ = address), do: KeyManager.checksum_address(address)

  defp resolve_address(wallet_id) do
    case get_wallet(wallet_id) do
      {:ok, wallet} -> {:ok, wallet.address}
      error -> error
    end
  end

  defp find_by_address(address) do
    with {:ok, checksummed} <- KeyManager.checksum_address(address) do
      @wallet_table
      |> :ets.tab2list()
      |> Enum.find_value({:error, :not_found}, fn {_id, wallet} ->
        if wallet.address == checksummed, do: {:ok, wallet}
      end)
    else
      _ -> {:error, :not_found}
    end
  end

  defp build_wallet(:standard, params) do
    passphrase = Map.get(params, :passphrase, @default_passphrase)

    priv_result =
      case Map.get(params, :private_key) do
        nil -> KeyManager.generate_private_key()
        provided ->
          case KeyManager.normalize_private_key(provided) do
            {:ok, _raw, hex} -> {:ok, hex}
            err -> err
          end
      end

    with {:ok, hex_priv} <- priv_result,
         {:ok, address} <- KeyManager.derive_address(hex_priv) do
      envelope = KeyManager.encrypt_secret(hex_priv, passphrase)

      {:ok,
       %__MODULE__{
         id: Map.get(params, :id) || UUID.generate(),
         name: Map.get(params, :name, "Standard Wallet"),
         type: :standard,
         address: address,
         accounts: [%{index: 0, path: "m/44'/60'/0'/0/0", address: address}],
         encrypted_secret: envelope,
         chains: Map.get(params, :chains, [:ethereum, :arbitrum, :optimism, :base, :polygon]),
         metadata: Map.get(params, :metadata, %{}),
         created_at: DateTime.utc_now()
       }}
    end
  end

  defp build_wallet(:hd, params) do
    passphrase = Map.get(params, :passphrase, @default_passphrase)
    path = Map.get(params, :derivation_path, "m/44'/60'/0'/0/0")

    seed =
      cond do
        is_binary(params[:seed]) and byte_size(params[:seed]) == 64 ->
          params[:seed]

        is_binary(params[:mnemonic]) ->
          pass = Map.get(params, :mnemonic_passphrase, "")
          KeyManager.seed_from_phrase(params[:mnemonic], pass)

        true ->
          :crypto.strong_rand_bytes(64)
      end

    with {:ok, derived} <- KeyManager.derive_hd_key(seed, path) do
      envelope = KeyManager.encrypt_secret(seed, passphrase)

      {:ok,
       %__MODULE__{
         id: Map.get(params, :id) || UUID.generate(),
         name: Map.get(params, :name, "HD Wallet"),
         type: :hd,
         address: derived.address,
         derivation_path: path,
         accounts: [%{index: 0, path: path, address: derived.address}],
         encrypted_secret: envelope,
         chains: Map.get(params, :chains, [:ethereum, :arbitrum, :optimism, :base, :polygon]),
         metadata: Map.get(params, :metadata, %{}),
         created_at: DateTime.utc_now()
       }}
    end
  end

  defp build_wallet(:hardware, params) do
    address = Map.get(params, :address)
    signer = Map.get(params, :hardware_signer)
    path = Map.get(params, :derivation_path, "m/44'/60'/0'/0/0")

    with {:ok, checksummed} <- KeyManager.checksum_address(to_string(address)),
         true <- is_function(signer, 2) or {:error, :invalid_hardware_signer} do
      {:ok,
       %__MODULE__{
         id: Map.get(params, :id) || UUID.generate(),
         name: Map.get(params, :name, "Hardware Wallet"),
         type: :hardware,
         address: checksummed,
         derivation_path: path,
         accounts: [%{index: 0, path: path, address: checksummed}],
         hardware_signer: signer,
         chains: Map.get(params, :chains, [:ethereum, :arbitrum, :optimism, :base, :polygon]),
         metadata: Map.get(params, :metadata, %{device: Map.get(params, :device, "ledger")}),
         created_at: DateTime.utc_now()
       }}
    end
  end

  defp build_wallet(:multisig, params) do
    raw_owners = Map.get(params, :owners, [])
    threshold = Map.get(params, :threshold, 1)

    with {:ok, owners} <- validate_owners(raw_owners),
         true <-
           (is_integer(threshold) and threshold >= 1 and threshold <= length(owners)) or
             {:error, :invalid_threshold} do
      address =
        case Map.get(params, :address) do
          nil -> derive_multisig_address(owners, threshold)
          explicit ->
            case KeyManager.checksum_address(explicit) do
              {:ok, addr} -> addr
              _ -> derive_multisig_address(owners, threshold)
            end
        end

      {:ok,
       %__MODULE__{
         id: Map.get(params, :id) || UUID.generate(),
         name: Map.get(params, :name, "MultiSig Wallet"),
         type: :multisig,
         address: address,
         owners: owners,
         threshold: threshold,
         chains: Map.get(params, :chains, [:ethereum, :arbitrum, :optimism, :base, :polygon]),
         metadata: Map.get(params, :metadata, %{}),
         created_at: DateTime.utc_now()
       }}
    end
  end

  defp build_wallet(other, _params), do: {:error, {:unsupported_wallet_type, other}}

  defp validate_owners(owners) when is_list(owners) and owners != [] do
    owners
    |> Enum.reduce_while({:ok, []}, fn owner, {:ok, acc} ->
      case KeyManager.checksum_address(to_string(owner)) do
        {:ok, addr} -> {:cont, {:ok, [addr | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, list |> Enum.reverse() |> Enum.uniq()}
      error -> error
    end
  end

  defp validate_owners(_), do: {:error, :invalid_owners}

  defp derive_multisig_address(owners, threshold) do
    seed = Enum.join(owners, ":") <> ":threshold=#{threshold}"
    <<_::binary-size(12), addr_bytes::binary-size(20)>> = KeyManager.keccak256(seed)
    raw_hex = "0x" <> Base.encode16(addr_bytes, case: :lower)
    {:ok, checksummed} = KeyManager.checksum_address(raw_hex)
    checksummed
  end

  defp extract_wallet_private_key(
         %__MODULE__{type: :standard, encrypted_secret: env},
         passphrase,
         _path
       ) do
    KeyManager.decrypt_secret(env, passphrase)
  end

  defp extract_wallet_private_key(
         %__MODULE__{type: :hd, encrypted_secret: env, derivation_path: default_path},
         passphrase,
         path
       ) do
    target_path = path || default_path || "m/44'/60'/0'/0/0"

    with {:ok, seed} <- KeyManager.decrypt_secret(env, passphrase),
         {:ok, derived} <- KeyManager.derive_hd_key(seed, target_path) do
      {:ok, derived.private_key}
    end
  end

  defp extract_wallet_private_key(%__MODULE__{type: type}, _passphrase, _path) do
    {:error, {:private_key_export_unsupported, type}}
  end

  defp ensure_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end
end
