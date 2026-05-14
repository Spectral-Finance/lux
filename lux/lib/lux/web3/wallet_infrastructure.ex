defmodule Lux.Web3.WalletInfrastructure do
  @moduledoc """
  Offline wallet and transaction infrastructure for EVM chains.

  The module deliberately separates signer references from private key material. Wallet creation and
  private-key import can derive addresses for local development, but returned wallet records only
  contain a key fingerprint unless `include_private_key: true` is passed explicitly.
  """

  alias Ethers.Signer.Local, as: LocalSigner
  alias Ethers.Transaction
  alias Ethers.Transaction.Eip1559
  alias Ethers.Utils

  @wallet_types [:local, :imported, :hd, :hardware, :multi_sig, :external]
  @transaction_statuses [
    :planned,
    :queued,
    :signing,
    :signed,
    :broadcast,
    :confirmed,
    :failed,
    :dropped
  ]

  @chains %{
    ethereum: %{
      id: :ethereum,
      chain_id: 1,
      name: "Ethereum",
      native_symbol: "ETH",
      rpc_env: "ETHEREUM_RPC_URL",
      explorer: "https://etherscan.io"
    },
    sepolia: %{
      id: :sepolia,
      chain_id: 11_155_111,
      name: "Sepolia",
      native_symbol: "ETH",
      rpc_env: "SEPOLIA_RPC_URL",
      explorer: "https://sepolia.etherscan.io"
    },
    polygon: %{
      id: :polygon,
      chain_id: 137,
      name: "Polygon",
      native_symbol: "MATIC",
      rpc_env: "POLYGON_RPC_URL",
      explorer: "https://polygonscan.com"
    },
    arbitrum: %{
      id: :arbitrum,
      chain_id: 42_161,
      name: "Arbitrum One",
      native_symbol: "ETH",
      rpc_env: "ARBITRUM_RPC_URL",
      explorer: "https://arbiscan.io"
    },
    optimism: %{
      id: :optimism,
      chain_id: 10,
      name: "Optimism",
      native_symbol: "ETH",
      rpc_env: "OPTIMISM_RPC_URL",
      explorer: "https://optimistic.etherscan.io"
    },
    base: %{
      id: :base,
      chain_id: 8453,
      name: "Base",
      native_symbol: "ETH",
      rpc_env: "BASE_RPC_URL",
      explorer: "https://basescan.org"
    },
    bnb: %{
      id: :bnb,
      chain_id: 56,
      name: "BNB Smart Chain",
      native_symbol: "BNB",
      rpc_env: "BNB_RPC_URL",
      explorer: "https://bscscan.com"
    }
  }

  @doc "Returns supported chain metadata."
  def supported_chains do
    @chains
    |> Map.values()
    |> Enum.sort_by(& &1.chain_id)
  end

  @doc "Looks up chain metadata by id, string id, or numeric EVM chain id."
  def chain(chain_id) do
    case normalize_chain_key(chain_id) do
      {:ok, key} -> {:ok, Map.fetch!(@chains, key)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Creates a local EVM wallet record."
  def create_wallet(attrs \\ %{}) when is_map(attrs) do
    private_key = value(attrs, :private_key) || generate_private_key()

    with {:ok, wallet} <- wallet_from_private_key(private_key, :local, attrs) do
      maybe_include_private_key(wallet, private_key, truthy?(value(attrs, :include_private_key)))
    end
  end

  @doc "Imports a private key into an offline wallet record."
  def import_wallet(private_key, attrs \\ %{}) when is_map(attrs) do
    wallet_from_private_key(private_key, :imported, attrs)
  end

  @doc "Registers an external, HD, hardware, local-address, or multi-signature wallet."
  def register_wallet(attrs) when is_map(attrs) do
    type = attrs |> value(:type, :external) |> normalize_atom()

    with :ok <- ensure_wallet_type(type),
         {:ok, address} <- normalize_address(value(attrs, :address)),
         {:ok, chain} <- chain(value(attrs, :chain, :ethereum)),
         {:ok, signer} <- signer_reference(type, attrs),
         {:ok, policy} <- signing_policy(type, attrs) do
      {:ok,
       %{
         id: value(attrs, :id) || wallet_id(type, address, signer),
         type: type,
         address: address,
         chain: chain.id,
         chain_id: chain.chain_id,
         label: value(attrs, :label),
         signer: signer,
         policy: policy,
         metadata: value(attrs, :metadata, %{}),
         created_at: timestamp(value(attrs, :now))
       }}
    end
  end

  @doc "Builds an HD child wallet reference from a parent fingerprint and derivation path."
  def derive_hd_wallet(parent, index, attrs \\ %{}) do
    with {:ok, path} <- derive_hd_path(value(parent, :path, "m/44'/60'/0'/0"), index),
         {:ok, address} <- normalize_address(value(attrs, :address)) do
      register_wallet(%{
        type: :hd,
        address: address,
        chain: value(attrs, :chain, value(parent, :chain, :ethereum)),
        label: value(attrs, :label),
        path: path,
        root_fingerprint: value(parent, :root_fingerprint),
        signer_ref: value(attrs, :signer_ref, value(parent, :signer_ref))
      })
    end
  end

  @doc "Derives the next BIP-44 style child path reference."
  def derive_hd_path(base_path, index) when is_integer(index) and index >= 0 do
    base_path = String.trim(to_string(base_path || ""))

    if Regex.match?(~r/^m(\/[0-9]+'?)*$/, base_path) do
      {:ok, "#{base_path}/#{index}"}
    else
      {:error, :invalid_hd_path}
    end
  end

  def derive_hd_path(_base_path, _index), do: {:error, :invalid_hd_index}

  @doc "Builds an offline EIP-1559 transaction plan."
  def build_transaction(attrs) when is_map(attrs) do
    with {:ok, chain} <- chain(value(attrs, :chain, :ethereum)),
         {:ok, from} <- normalize_address(value(attrs, :from)),
         {:ok, to} <- normalize_optional_address(value(attrs, :to)),
         {:ok, value_wei} <-
           non_negative_integer(value(attrs, :value_wei, value(attrs, :value, 0))),
         {:ok, nonce} <- non_negative_integer(value(attrs, :nonce, 0)),
         {:ok, input} <- transaction_input(value(attrs, :data, value(attrs, :input, "0x"))),
         {:ok, fee} <- estimate_fee(attrs) do
      request = %{
        type: Eip1559,
        chain_id: chain.chain_id,
        nonce: nonce,
        gas: fee.gas_limit,
        max_priority_fee_per_gas: fee.max_priority_fee_per_gas,
        max_fee_per_gas: fee.max_fee_per_gas,
        from: from,
        to: to,
        value: value_wei,
        input: input,
        access_list: value(attrs, :access_list, [])
      }

      {:ok,
       %{
         id: value(attrs, :id) || transaction_id(chain.chain_id, from, to, nonce, input),
         status: :planned,
         chain: chain,
         request: request,
         rpc_payload: rpc_payload(request),
         fee: fee,
         policy: %{
           required_wallet: from,
           signer_types: [:local, :hardware, :multi_sig, :json_rpc],
           broadcast_method: "eth_sendRawTransaction"
         },
         created_at: timestamp(value(attrs, :now))
       }}
    end
  end

  @doc "Estimates EIP-1559 fee bounds from provided gas and base fee observations."
  def estimate_fee(attrs) when is_map(attrs) do
    with {:ok, gas_limit} <-
           non_negative_integer(value(attrs, :gas, value(attrs, :gas_limit, 21_000))),
         {:ok, priority} <-
           non_negative_integer(
             value(attrs, :max_priority_fee_per_gas, value(attrs, :priority_fee, 1_500_000_000))
           ),
         {:ok, max_fee} <- max_fee_per_gas(attrs, priority) do
      {:ok,
       %{
         gas_limit: gas_limit,
         max_priority_fee_per_gas: priority,
         max_fee_per_gas: max_fee,
         max_total_fee_wei: gas_limit * max_fee
       }}
    end
  end

  @doc "Signs a transaction plan with a local private key signer."
  def sign_transaction(%{request: request} = plan, signer) when is_map(signer) do
    private_key = value(signer, :private_key)

    with {:ok, signer_address} <- private_key_address(private_key),
         :ok <- ensure_signer_matches(request.from, signer_address),
         {:ok, tx} <- Transaction.new(request),
         {:ok, raw_transaction} <-
           LocalSigner.sign_transaction(tx,
             private_key: private_key,
             from: request.from
           ) do
      {:ok,
       plan
       |> Map.put(:status, :signed)
       |> Map.put(:signed, %{
         signer: signer_address,
         raw_transaction: raw_transaction,
         transaction_hash: transaction_hash(raw_transaction),
         signed_at: timestamp(value(signer, :now))
       })}
    end
  end

  def sign_transaction(_plan, _signer), do: {:error, :invalid_transaction_plan}

  @doc "Builds the JSON-RPC broadcast request for a signed transaction."
  def broadcast_plan(%{signed: signed, chain: chain} = plan) do
    {:ok,
     plan
     |> Map.put(:status, :broadcast)
     |> Map.put(:broadcast, %{
       chain: chain.id,
       chain_id: chain.chain_id,
       method: "eth_sendRawTransaction",
       params: [signed.raw_transaction],
       transaction_hash: signed.transaction_hash
     })}
  end

  def broadcast_plan(_plan), do: {:error, :missing_signed_transaction}

  @doc "Creates an empty transaction queue."
  def new_queue(attrs \\ %{}) do
    %{
      id: value(attrs, :id, "wallet-transaction-queue"),
      transactions: [],
      created_at: timestamp(value(attrs, :now))
    }
  end

  @doc "Adds a transaction plan to the queue."
  def enqueue_transaction(queue, plan, attrs \\ %{}) when is_map(queue) and is_map(plan) do
    queued =
      plan
      |> Map.put(:status, :queued)
      |> Map.put(:queued_at, timestamp(value(attrs, :now)))
      |> append_history(:queued, "transaction queued", attrs)

    {:ok, Map.update(queue, :transactions, [queued], &[queued | &1])}
  end

  @doc "Advances a queued transaction to a new status."
  def advance_transaction(queue, transaction_id, status, attrs \\ %{}) do
    status = normalize_atom(status)

    with :ok <- ensure_transaction_status(status) do
      update_transaction(queue, transaction_id, fn tx ->
        tx
        |> Map.put(:status, status)
        |> append_history(status, value(attrs, :message, "status changed"), attrs)
      end)
    end
  end

  @doc "Records a broadcast hash and marks a queued transaction as broadcast."
  def record_broadcast(queue, transaction_id, tx_hash, attrs \\ %{}) do
    update_transaction(queue, transaction_id, fn tx ->
      tx
      |> Map.put(:status, :broadcast)
      |> Map.put(:broadcast, %{
        transaction_hash: tx_hash,
        broadcaster: value(attrs, :broadcaster),
        broadcast_at: timestamp(value(attrs, :now))
      })
      |> append_history(:broadcast, "transaction broadcast", attrs)
    end)
  end

  @doc "Records a confirmation receipt and marks the transaction as confirmed."
  def record_confirmation(queue, transaction_id, receipt, attrs \\ %{}) do
    update_transaction(queue, transaction_id, fn tx ->
      tx
      |> Map.put(:status, :confirmed)
      |> Map.put(:receipt, normalize_receipt(receipt))
      |> append_history(:confirmed, "transaction confirmed", attrs)
    end)
  end

  @doc "Records a terminal transaction failure."
  def record_failure(queue, transaction_id, reason, attrs \\ %{}) do
    update_transaction(queue, transaction_id, fn tx ->
      tx
      |> Map.put(:status, :failed)
      |> Map.put(:failure, %{reason: reason, failed_at: timestamp(value(attrs, :now))})
      |> append_history(:failed, to_string(reason), attrs)
    end)
  end

  @doc "Applies transaction receipts to a queue, returning an updated queue."
  def monitor_transactions(queue, receipts, attrs \\ %{}) when is_map(receipts) do
    Enum.reduce_while(queue.transactions || [], {:ok, queue}, fn tx, {:ok, acc} ->
      tx
      |> receipt_for(receipts)
      |> apply_receipt(acc, tx.id, attrs)
    end)
  end

  @doc "Normalizes a multi-chain balance snapshot for wallets."
  def balance_snapshot(wallets, balances, attrs \\ %{}) when is_list(wallets) do
    chain_id = value(attrs, :chain, :ethereum)

    with {:ok, chain} <- chain(chain_id) do
      entries =
        Enum.map(wallets, fn wallet ->
          address = wallet.address
          balance = Map.get(balances, address) || Map.get(balances, String.downcase(address)) || 0

          %{
            wallet_id: wallet.id,
            address: address,
            chain: chain.id,
            chain_id: chain.chain_id,
            balance_wei: balance,
            balance_native: Utils.from_wei(balance),
            observed_at: timestamp(value(attrs, :now))
          }
        end)

      {:ok,
       %{
         chain: chain.id,
         chain_id: chain.chain_id,
         total_wei: Enum.reduce(entries, 0, &(&1.balance_wei + &2)),
         wallets: entries
       }}
    end
  end

  defp wallet_from_private_key(private_key, type, attrs) do
    with {:ok, private_key_bin} <- decode_private_key(private_key),
         {:ok, public_key} <- Ethers.secp256k1_module().create_public_key(private_key_bin),
         {:ok, chain} <- chain(value(attrs, :chain, :ethereum)) do
      address = Utils.public_key_to_address(public_key)
      key_ref = key_fingerprint(private_key_bin)

      {:ok,
       %{
         id: value(attrs, :id) || wallet_id(type, address, %{key_ref: key_ref}),
         type: type,
         address: address,
         chain: chain.id,
         chain_id: chain.chain_id,
         public_key: Utils.hex_encode(public_key),
         signer: %{
           strategy: :local_private_key,
           key_ref: key_ref,
           key_fingerprint: key_ref
         },
         policy: %{
           can_sign: true,
           exposes_private_key: false,
           allowed_chains: [chain.id]
         },
         metadata: value(attrs, :metadata, %{}),
         created_at: timestamp(value(attrs, :now))
       }}
    end
  end

  defp maybe_include_private_key(wallet, private_key, true) do
    {:ok, put_in(wallet, [:signer, :private_key], normalize_private_key(private_key))}
  end

  defp maybe_include_private_key(wallet, _private_key, _include), do: {:ok, wallet}

  defp private_key_address(private_key) do
    with {:ok, private_key_bin} <- decode_private_key(private_key),
         {:ok, public_key} <- Ethers.secp256k1_module().create_public_key(private_key_bin) do
      {:ok, Utils.public_key_to_address(public_key)}
    end
  end

  defp signer_reference(:multi_sig, attrs) do
    signers = value(attrs, :signers, [])
    threshold = value(attrs, :threshold, 1)

    with {:ok, normalized_signers} <- normalize_signers(signers),
         {:ok, threshold} <- non_negative_integer(threshold),
         :ok <- validate_threshold(threshold, normalized_signers) do
      {:ok,
       %{
         strategy: :multi_sig,
         signers: normalized_signers,
         threshold: threshold
       }}
    end
  end

  defp signer_reference(:hd, attrs) do
    path = value(attrs, :path, value(attrs, :derivation_path))

    if is_binary(path) do
      {:ok,
       %{
         strategy: :hd_wallet,
         path: path,
         root_fingerprint: value(attrs, :root_fingerprint),
         signer_ref: value(attrs, :signer_ref)
       }}
    else
      {:error, :missing_hd_path}
    end
  end

  defp signer_reference(:hardware, attrs) do
    {:ok,
     %{
       strategy: :hardware_wallet,
       device: value(attrs, :device, "hardware-wallet"),
       path: value(attrs, :path, value(attrs, :derivation_path)),
       signer_ref: value(attrs, :signer_ref)
     }}
  end

  defp signer_reference(type, attrs) when type in [:local, :imported, :external] do
    {:ok,
     %{
       strategy: value(attrs, :strategy, :external_signer),
       signer_ref: value(attrs, :signer_ref),
       key_ref: value(attrs, :key_ref)
     }}
  end

  defp signing_policy(:multi_sig, attrs) do
    {:ok,
     %{
       can_sign: true,
       threshold: value(attrs, :threshold, 1),
       requires_online_approval: true
     }}
  end

  defp signing_policy(type, _attrs) when type in [:local, :imported] do
    {:ok, %{can_sign: true, exposes_private_key: false}}
  end

  defp signing_policy(:hardware, _attrs) do
    {:ok, %{can_sign: true, requires_device_confirmation: true}}
  end

  defp signing_policy(:hd, _attrs) do
    {:ok, %{can_sign: true, requires_derivation_path: true}}
  end

  defp signing_policy(:external, _attrs), do: {:ok, %{can_sign: false}}

  defp normalize_signers(signers) when is_list(signers) do
    signers
    |> Enum.reduce_while({:ok, []}, fn signer, {:ok, acc} ->
      case normalize_address(value(signer, :address, signer)) do
        {:ok, address} -> {:cont, {:ok, [%{address: address, role: value(signer, :role)} | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp normalize_signers(_signers), do: {:error, :invalid_signers}

  defp validate_threshold(threshold, signers) when threshold > 0 and threshold <= length(signers),
    do: :ok

  defp validate_threshold(_threshold, _signers), do: {:error, :invalid_threshold}

  defp max_fee_per_gas(attrs, priority) do
    case value(attrs, :max_fee_per_gas) do
      nil ->
        with {:ok, base_fee} <-
               non_negative_integer(value(attrs, :base_fee_per_gas, 20_000_000_000)) do
          {:ok, base_fee * 2 + priority}
        end

      max_fee ->
        non_negative_integer(max_fee)
    end
  end

  defp transaction_input(nil), do: {:ok, ""}
  defp transaction_input("0x"), do: {:ok, ""}

  defp transaction_input("0x" <> _ = hex) do
    case Utils.hex_decode(hex) do
      {:ok, bin} -> {:ok, bin}
      :error -> {:error, :invalid_transaction_data}
    end
  end

  defp transaction_input(bin) when is_binary(bin), do: {:ok, bin}
  defp transaction_input(_data), do: {:error, :invalid_transaction_data}

  defp rpc_payload(request) do
    request
    |> Map.take([
      :chain_id,
      :nonce,
      :gas,
      :max_priority_fee_per_gas,
      :max_fee_per_gas,
      :from,
      :to,
      :value,
      :input,
      :access_list
    ])
    |> Map.update!(:input, &Utils.hex_encode/1)
  end

  defp ensure_signer_matches(expected, actual) do
    if Utils.decode_address!(expected) == Utils.decode_address!(actual) do
      :ok
    else
      {:error, :wrong_key}
    end
  end

  defp update_transaction(queue, transaction_id, updater) do
    {transactions, updated?} =
      Enum.map_reduce(queue.transactions || [], false, fn tx, changed? ->
        if tx.id == transaction_id do
          {updater.(tx), true}
        else
          {tx, changed?}
        end
      end)

    if updated? do
      {:ok, %{queue | transactions: transactions}}
    else
      {:error, :transaction_not_found}
    end
  end

  defp continue_or_halt({:ok, queue}), do: {:cont, {:ok, queue}}
  defp continue_or_halt({:error, _reason} = error), do: {:halt, error}

  defp receipt_for(tx, receipts) do
    tx_hash =
      value(tx[:signed] || %{}, :transaction_hash) ||
        value(tx[:broadcast] || %{}, :transaction_hash)

    Map.get(receipts, tx_hash) || Map.get(receipts, to_string(tx_hash))
  end

  defp apply_receipt(nil, queue, _transaction_id, _attrs), do: {:cont, {:ok, queue}}

  defp apply_receipt(receipt, queue, transaction_id, attrs) do
    case receipt_status(receipt) do
      :confirmed -> record_confirmation(queue, transaction_id, receipt, attrs)
      :failed -> record_failure(queue, transaction_id, :receipt_failed, attrs)
      :pending -> advance_transaction(queue, transaction_id, :broadcast, attrs)
    end
    |> continue_or_halt()
  end

  defp append_history(tx, status, message, attrs) do
    entry = %{
      status: status,
      message: message,
      at: timestamp(value(attrs, :now))
    }

    Map.update(tx, :history, [entry], &(&1 ++ [entry]))
  end

  defp normalize_receipt(receipt) do
    %{
      transaction_hash: value(receipt, :transaction_hash, value(receipt, :transactionHash)),
      block_number: value(receipt, :block_number, value(receipt, :blockNumber)),
      status: receipt_status(receipt),
      raw: receipt
    }
  end

  defp receipt_status(receipt) do
    case value(receipt, :status) do
      value when value in [1, "0x1", "1", true, :ok, :confirmed] -> :confirmed
      value when value in [0, "0x0", "0", false, :failed] -> :failed
      _ -> :pending
    end
  end

  defp transaction_hash(raw_transaction) do
    raw_transaction
    |> Utils.hex_decode!()
    |> Ethers.keccak_module().hash_256()
    |> Utils.hex_encode()
  end

  defp transaction_id(chain_id, from, to, nonce, input) do
    material = "#{chain_id}:#{from}:#{to}:#{nonce}:#{Utils.hex_encode(input)}"

    "tx_" <> short_hash(material)
  end

  defp wallet_id(type, address, signer) do
    "wallet_#{type}_" <> short_hash("#{address}:#{inspect(signer)}")
  end

  defp key_fingerprint(private_key) do
    :crypto.hash(:sha256, private_key)
    |> binary_part(0, 8)
    |> Utils.hex_encode()
  end

  defp short_hash(material) do
    :crypto.hash(:sha256, material)
    |> binary_part(0, 8)
    |> Base.encode16(case: :lower)
  end

  defp generate_private_key do
    private_key = :crypto.strong_rand_bytes(32)

    case Ethers.secp256k1_module().create_public_key(private_key) do
      {:ok, _public_key} -> private_key
      _error -> generate_private_key()
    end
  end

  defp normalize_private_key(<<"0x", _::binary-64>> = private_key),
    do: String.downcase(private_key)

  defp normalize_private_key(<<_::binary-64>> = private_key),
    do: "0x" <> String.downcase(private_key)

  defp normalize_private_key(<<_::binary-32>> = private_key), do: Utils.hex_encode(private_key)

  defp decode_private_key(<<"0x", _::binary-64>> = private_key), do: Utils.hex_decode(private_key)
  defp decode_private_key(<<_::binary-64>> = private_key), do: Utils.hex_decode(private_key)
  defp decode_private_key(<<_::binary-32>> = private_key), do: {:ok, private_key}
  defp decode_private_key(_private_key), do: {:error, :invalid_private_key}

  defp normalize_optional_address(nil), do: {:ok, nil}
  defp normalize_optional_address(""), do: {:ok, nil}
  defp normalize_optional_address(address), do: normalize_address(address)

  defp normalize_address(address) when is_binary(address) do
    if Regex.match?(~r/^0x[0-9a-fA-F]{40}$/, address) do
      {:ok, Utils.to_checksum_address(address)}
    else
      {:error, :invalid_address}
    end
  end

  defp normalize_address(_address), do: {:error, :invalid_address}

  defp normalize_chain_key(chain_id) when is_atom(chain_id) do
    if Map.has_key?(@chains, chain_id), do: {:ok, chain_id}, else: {:error, :unsupported_chain}
  end

  defp normalize_chain_key(chain_id) when is_integer(chain_id) do
    @chains
    |> Enum.find(fn {_key, chain} -> chain.chain_id == chain_id end)
    |> case do
      {key, _chain} -> {:ok, key}
      nil -> {:error, :unsupported_chain}
    end
  end

  defp normalize_chain_key(chain_id) when is_binary(chain_id) do
    case Integer.parse(chain_id) do
      {integer, ""} -> normalize_chain_key(integer)
      _ -> chain_id |> String.downcase() |> String.to_atom() |> normalize_chain_key()
    end
  end

  defp normalize_chain_key(_chain_id), do: {:error, :unsupported_chain}

  defp ensure_wallet_type(type) when type in @wallet_types, do: :ok
  defp ensure_wallet_type(_type), do: {:error, :unsupported_wallet_type}

  defp ensure_transaction_status(status) when status in @transaction_statuses, do: :ok
  defp ensure_transaction_status(_status), do: {:error, :unsupported_transaction_status}

  defp non_negative_integer(value) when is_integer(value) and value >= 0, do: {:ok, value}

  defp non_negative_integer("0x" <> _ = value) do
    case Utils.hex_to_integer(value) do
      {:ok, integer} -> {:ok, integer}
      {:error, _reason} -> {:error, :invalid_integer}
    end
  end

  defp non_negative_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= 0 -> {:ok, integer}
      _ -> {:error, :invalid_integer}
    end
  end

  defp non_negative_integer(_value), do: {:error, :invalid_integer}

  defp normalize_atom(value) when is_atom(value), do: value

  defp normalize_atom(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  defp normalize_atom(value), do: value

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp value(_map, _key, default), do: default

  defp truthy?(value), do: value in [true, "true", "1", 1, true]

  defp timestamp(nil), do: DateTime.utc_now() |> DateTime.to_iso8601()
  defp timestamp(%DateTime{} = now), do: DateTime.to_iso8601(now)
  defp timestamp(now) when is_binary(now), do: now
end
