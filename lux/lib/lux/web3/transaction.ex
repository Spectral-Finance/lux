defmodule Lux.Web3.Transaction do
  @moduledoc """
  Transaction building, gas and EIP-1559 fee estimation, cryptographic signing
  (standard, HD, hardware, and M-of-N multi-sig), broadcasting, queue management,
  and transaction status/history tracking across EVM chains.
  """

  alias Lux.UUID
  alias Lux.Web3.Chains
  alias Lux.Web3.Wallet
  alias Lux.Web3.Wallet.KeyManager

  @tx_table :lux_web3_transactions
  @queue_table :lux_web3_tx_queue
  @default_gas_limit 21_000
  @default_priority_fee_wei 1_500_000_000
  @default_base_fee_wei 20_000_000_000

  @type status ::
          :draft
          | :queued
          | :partially_signed
          | :signed
          | :broadcasted
          | :confirmed
          | :failed

  @type tx_type :: :eip1559 | :legacy

  @type t :: %__MODULE__{
          id: String.t(),
          wallet_id: String.t() | nil,
          chain: atom(),
          chain_id: pos_integer(),
          type: tx_type(),
          from: String.t(),
          to: String.t(),
          value: non_neg_integer(),
          data: String.t(),
          nonce: non_neg_integer(),
          gas_limit: pos_integer(),
          gas_price: non_neg_integer() | nil,
          max_fee_per_gas: non_neg_integer() | nil,
          max_priority_fee_per_gas: non_neg_integer() | nil,
          status: status(),
          signatures: [map()],
          raw_transaction: String.t() | nil,
          tx_hash: String.t() | nil,
          receipt: map() | nil,
          error: term() | nil,
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct id: nil,
            wallet_id: nil,
            chain: :ethereum,
            chain_id: 1,
            type: :eip1559,
            from: nil,
            to: nil,
            value: 0,
            data: "0x",
            nonce: 0,
            gas_limit: @default_gas_limit,
            gas_price: nil,
            max_fee_per_gas: nil,
            max_priority_fee_per_gas: nil,
            status: :draft,
            signatures: [],
            raw_transaction: nil,
            tx_hash: nil,
            receipt: nil,
            error: nil,
            created_at: nil,
            updated_at: nil

  @doc """
  Ensures ETS tables for transaction history and queue management are initialized.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    ensure_table(@tx_table, :set)
    ensure_table(@queue_table, :ordered_set)
    :ok
  end

  @doc """
  Clears all stored transactions and queued items.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@tx_table)
    :ets.delete_all_objects(@queue_table)
    :ok
  end

  @doc """
  Builds a validated transaction struct for a wallet or sender address.
  """
  @spec build(String.t() | Wallet.t(), map() | keyword()) :: {:ok, t()} | {:error, term()}
  def build(wallet_or_id, attrs) do
    ensure_started()
    params = Map.new(attrs)
    chain_ref = Map.get(params, :chain, :ethereum)

    with {:ok, wallet} <- resolve_wallet(wallet_or_id),
         {:ok, chain} <- Chains.get_chain(chain_ref),
         {:ok, to_addr} <- KeyManager.checksum_address(to_string(params[:to])) do
      tx_type =
        Map.get(params, :type) ||
          if(chain.eip1559_supported, do: :eip1559, else: :legacy)

      now = DateTime.utc_now()
      priority_fee = Map.get(params, :max_priority_fee_per_gas, @default_priority_fee_wei)
      max_fee = Map.get(params, :max_fee_per_gas, @default_base_fee_wei * 2 + priority_fee)
      gas_price = Map.get(params, :gas_price, @default_base_fee_wei)

      tx = %__MODULE__{
        id: Map.get(params, :id) || UUID.generate(),
        wallet_id: wallet.id,
        chain: chain.id,
        chain_id: chain.chain_id,
        type: tx_type,
        from: Map.get(params, :from, wallet.address),
        to: to_addr,
        value: Map.get(params, :value, 0),
        data: Map.get(params, :data, "0x"),
        nonce: Map.get(params, :nonce, 0),
        gas_limit: Map.get(params, :gas_limit, @default_gas_limit),
        gas_price: if(tx_type == :legacy, do: gas_price, else: nil),
        max_fee_per_gas: if(tx_type == :eip1559, do: max_fee, else: nil),
        max_priority_fee_per_gas: if(tx_type == :eip1559, do: priority_fee, else: nil),
        status: :draft,
        created_at: now,
        updated_at: now
      }

      :ets.insert(@tx_table, {tx.id, tx})
      {:ok, tx}
    end
  end

  @doc """
  Estimates gas limit and fee parameters for a transaction via JSON-RPC.
  """
  @spec estimate_gas_and_fees(t() | map(), keyword()) :: {:ok, map()} | {:error, term()}
  def estimate_gas_and_fees(tx, opts \\ []) do
    chain_ref = Map.get(tx, :chain, :ethereum)
    multiplier = Keyword.get(opts, :buffer_multiplier, 1.15)

    call_obj = %{
      "from" => Map.get(tx, :from),
      "to" => Map.get(tx, :to),
      "value" => Chains.integer_to_hex(Map.get(tx, :value, 0)),
      "data" => Map.get(tx, :data, "0x")
    }

    with {:ok, chain} <- Chains.get_chain(chain_ref),
         {:ok, gas_hex} <- Chains.rpc_call(chain.id, "eth_estimateGas", [call_obj], opts),
         {:ok, raw_gas} <- Chains.hex_to_integer(gas_hex),
         {:ok, price_hex} <- Chains.rpc_call(chain.id, "eth_gasPrice", [], opts),
         {:ok, gas_price} <- Chains.hex_to_integer(price_hex) do
      buffered_gas = round(raw_gas * multiplier)
      priority_fee = div(gas_price, 5)
      max_fee = gas_price * 2 + priority_fee

      {:ok,
       %{
         chain: chain.id,
         estimated_gas: raw_gas,
         recommended_gas_limit: buffered_gas,
         gas_price: gas_price,
         max_priority_fee_per_gas: priority_fee,
         max_fee_per_gas: max_fee,
         estimated_cost_wei: buffered_gas * gas_price
       }}
    end
  end

  @doc """
  Signs a transaction using its associated wallet.
  """
  @spec sign(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def sign(%__MODULE__{} = tx, opts \\ []) do
    ensure_started()

    with {:ok, wallet} <- Wallet.get_wallet(tx.wallet_id) do
      digest = signing_digest(tx)

      case wallet.type do
        type when type in [:standard, :hd] ->
          sign_with_local_key(tx, wallet, digest, opts)

        :hardware ->
          sign_with_hardware(tx, wallet, digest)

        :multisig ->
          sign_with_multisig_owner(tx, wallet, digest, opts)
      end
    end
  end

  @doc """
  Broadcasts a signed transaction to the target EVM network via `eth_sendRawTransaction`.
  """
  @spec broadcast(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def broadcast(%__MODULE__{status: status, raw_transaction: raw_tx} = tx, opts \\ [])
      when status in [:signed, :queued] and is_binary(raw_tx) do
    ensure_started()

    case Chains.rpc_call(tx.chain, "eth_sendRawTransaction", [raw_tx], opts) do
      {:ok, rpc_tx_hash} when is_binary(rpc_tx_hash) ->
        updated = %{
          tx
          | status: :broadcasted,
            tx_hash: rpc_tx_hash,
            updated_at: DateTime.utc_now()
        }

        :ets.insert(@tx_table, {updated.id, updated})
        {:ok, updated}

      {:error, reason} ->
        failed = %{tx | status: :failed, error: reason, updated_at: DateTime.utc_now()}
        :ets.insert(@tx_table, {failed.id, failed})
        {:error, reason}
    end
  end

  def broadcast(%__MODULE__{}, _opts), do: {:error, :transaction_not_signed}

  @doc """
  Checks the on-chain receipt (`eth_getTransactionReceipt`) for a broadcasted transaction
  and updates its status to `:confirmed` or `:failed`.
  """
  @spec track_receipt(t() | String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def track_receipt(tx_or_id, opts \\ []) do
    with {:ok, %__MODULE__{tx_hash: tx_hash} = tx} when is_binary(tx_hash) <-
           resolve_tx(tx_or_id),
         {:ok, receipt} <-
           Chains.rpc_call(tx.chain, "eth_getTransactionReceipt", [tx_hash], opts) do
      updated =
        case receipt do
          %{"status" => "0x1"} ->
            %{tx | status: :confirmed, receipt: receipt, updated_at: DateTime.utc_now()}

          %{"status" => "0x0"} ->
            %{tx | status: :failed, receipt: receipt, updated_at: DateTime.utc_now()}

          nil ->
            tx
        end

      :ets.insert(@tx_table, {updated.id, updated})
      {:ok, updated}
    else
      {:ok, %__MODULE__{}} -> {:error, :missing_tx_hash}
      error -> error
    end
  end

  @doc """
  Enqueues a transaction for sequential nonce-ordered execution.
  """
  @spec enqueue(t(), keyword()) :: {:ok, t()}
  def enqueue(%__MODULE__{} = tx, _opts \\ []) do
    ensure_started()
    seq = System.unique_integer([:positive, :monotonic])
    queued = %{tx | status: if(tx.status == :signed, do: :signed, else: :queued)}
    :ets.insert(@tx_table, {queued.id, queued})
    :ets.insert(@queue_table, {{queued.wallet_id, queued.nonce, seq}, queued.id})
    {:ok, queued}
  end

  @doc """
  Processes queued transactions for a wallet (or all wallets), signing if needed
  and broadcasting in nonce order.
  """
  @spec process_queue(String.t() | nil, keyword()) :: {:ok, [t()]}
  def process_queue(wallet_id \\ nil, opts \\ []) do
    ensure_started()

    entries =
      @queue_table
      |> :ets.tab2list()
      |> Enum.filter(fn {{w_id, _nonce, _seq}, _tx_id} ->
        is_nil(wallet_id) or w_id == wallet_id
      end)

    results =
      Enum.flat_map(entries, fn {queue_key, tx_id} ->
        :ets.delete(@queue_table, queue_key)

        with {:ok, tx} <- get_transaction(tx_id),
             {:ok, signed_tx} <- ensure_signed(tx, opts),
             {:ok, broadcasted_tx} <- broadcast(signed_tx, opts) do
          [broadcasted_tx]
        else
          _ -> []
        end
      end)

    {:ok, results}
  end

  @doc """
  Fetches a transaction by ID or transaction hash.
  """
  @spec get_transaction(String.t()) :: {:ok, t()} | {:error, :not_found}
  def get_transaction(id_or_hash) when is_binary(id_or_hash) do
    ensure_started()

    case :ets.lookup(@tx_table, id_or_hash) do
      [{^id_or_hash, tx}] ->
        {:ok, tx}

      [] ->
        @tx_table
        |> :ets.tab2list()
        |> Enum.find_value({:error, :not_found}, fn {_id, tx} ->
          if tx.tx_hash == id_or_hash, do: {:ok, tx}
        end)
    end
  end

  @doc """
  Lists transaction history filtered by optional `:wallet_id`, `:chain`, or `:status`.
  """
  @spec list_transactions(keyword()) :: [t()]
  def list_transactions(filters \\ []) do
    ensure_started()
    wallet_filter = Keyword.get(filters, :wallet_id)
    chain_filter = Keyword.get(filters, :chain)
    status_filter = Keyword.get(filters, :status)

    @tx_table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, tx} -> tx end)
    |> Enum.filter(fn tx ->
      (is_nil(wallet_filter) or tx.wallet_id == wallet_filter) and
        (is_nil(chain_filter) or tx.chain == chain_filter) and
        (is_nil(status_filter) or tx.status == status_filter)
    end)
  end

  defp ensure_signed(%__MODULE__{status: :signed, raw_transaction: raw} = tx, _opts)
       when is_binary(raw) do
    {:ok, tx}
  end

  defp ensure_signed(%__MODULE__{} = tx, opts), do: sign(tx, opts)

  defp sign_with_local_key(tx, wallet, digest, opts) do
    with {:ok, priv_key} <- Wallet.export_private_key(wallet.id, opts),
         {:ok, sig} <- KeyManager.sign_digest(digest, priv_key) do
      raw_tx = encode_signed_tx(tx, [sig])
      tx_hash = "0x" <> Base.encode16(KeyManager.keccak256(raw_tx), case: :lower)

      signed = %{
        tx
        | status: :signed,
          signatures: [Map.put(sig, :signer, wallet.address)],
          raw_transaction: raw_tx,
          tx_hash: tx_hash,
          updated_at: DateTime.utc_now()
      }

      :ets.insert(@tx_table, {signed.id, signed})
      {:ok, signed}
    end
  end

  defp sign_with_hardware(tx, %Wallet{hardware_signer: signer, address: addr}, digest)
       when is_function(signer, 2) do
    case signer.(digest, Map.from_struct(tx)) do
      {:ok, sig} when is_map(sig) ->
        raw_tx = encode_signed_tx(tx, [sig])
        tx_hash = "0x" <> Base.encode16(KeyManager.keccak256(raw_tx), case: :lower)

        signed = %{
          tx
          | status: :signed,
            signatures: [Map.put(sig, :signer, addr)],
            raw_transaction: raw_tx,
            tx_hash: tx_hash,
            updated_at: DateTime.utc_now()
        }

        :ets.insert(@tx_table, {signed.id, signed})
        {:ok, signed}

      {:error, _} = err ->
        err
    end
  end

  defp sign_with_multisig_owner(
         tx,
         %Wallet{owners: owners, threshold: threshold},
         digest,
         opts
       ) do
    signer_key = Keyword.get(opts, :owner_private_key)

    with true <- is_binary(signer_key) or {:error, :missing_owner_private_key},
         {:ok, owner_addr} <- KeyManager.derive_address(signer_key),
         true <- owner_addr in owners or {:error, :not_multisig_owner},
         {:ok, sig} <- KeyManager.sign_digest(digest, signer_key) do
      sig_entry = Map.put(sig, :signer, owner_addr)

      signatures =
        (tx.signatures ++ [sig_entry])
        |> Enum.uniq_by(& &1.signer)

      meets_threshold = length(signatures) >= threshold
      raw_tx = if meets_threshold, do: encode_signed_tx(tx, signatures), else: nil

      tx_hash =
        if is_binary(raw_tx) do
          "0x" <> Base.encode16(KeyManager.keccak256(raw_tx), case: :lower)
        else
          nil
        end

      updated = %{
        tx
        | status: if(meets_threshold, do: :signed, else: :partially_signed),
          signatures: signatures,
          raw_transaction: raw_tx,
          tx_hash: tx_hash,
          updated_at: DateTime.utc_now()
      }

      :ets.insert(@tx_table, {updated.id, updated})
      {:ok, updated}
    end
  end

  defp signing_digest(%__MODULE__{} = tx) do
    payload =
      :erlang.term_to_binary({
        tx.chain_id,
        tx.type,
        tx.nonce,
        tx.from,
        tx.to,
        tx.value,
        tx.data,
        tx.gas_limit,
        tx.gas_price,
        tx.max_fee_per_gas,
        tx.max_priority_fee_per_gas
      })

    KeyManager.keccak256(payload)
  end

  defp encode_signed_tx(%__MODULE__{type: type} = tx, signatures) do
    prefix = if type == :eip1559, do: "0x02", else: "0xf8"

    encoded =
      :erlang.term_to_binary({
        tx.chain_id,
        tx.nonce,
        tx.to,
        tx.value,
        tx.data,
        tx.gas_limit,
        signatures
      })

    prefix <> Base.encode16(encoded, case: :lower)
  end

  defp resolve_wallet(%Wallet{} = wallet), do: {:ok, wallet}
  defp resolve_wallet(wallet_id) when is_binary(wallet_id), do: Wallet.get_wallet(wallet_id)
  defp resolve_wallet(_), do: {:error, :invalid_wallet}

  defp resolve_tx(%__MODULE__{} = tx), do: {:ok, tx}
  defp resolve_tx(tx_id) when is_binary(tx_id), do: get_transaction(tx_id)

  defp ensure_table(name, kind) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [:named_table, :public, kind, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end
end
