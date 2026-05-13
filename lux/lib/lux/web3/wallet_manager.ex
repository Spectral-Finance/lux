defmodule Lux.Web3.WalletManager do
  @moduledoc """
  Safe wallet and transaction-management helpers.

  This module intentionally does not create, import, store, or expose private
  keys. It provides wallet registry records, signer policy checks, transaction
  request normalization, queue state transitions, balance snapshots, transaction
  history entries, and offline signing/broadcast plans.
  """

  @wallet_types [:external, :hardware, :hd, :multisig]
  @queue_states [:queued, :ready_to_sign, :signed, :broadcast, :confirmed, :failed, :canceled]

  @doc """
  Builds a wallet registry record without key material.
  """
  @spec wallet_record(map()) :: {:ok, map()} | {:error, String.t()}
  def wallet_record(attrs) when is_map(attrs) do
    type = value(attrs, :type) || :external
    address = value(attrs, :address)

    cond do
      type not in @wallet_types ->
        {:error, "Unsupported wallet type: #{type}"}

      not valid_address?(address) ->
        {:error, "Invalid EVM wallet address"}

      true ->
        {:ok,
         %{
           id: value(attrs, :id) || "wallet-#{String.downcase(address)}",
           type: type,
           address: normalize_address(address),
           label: value(attrs, :label),
           chains: value(attrs, :chains) || [],
           signer_ref: value(attrs, :signer_ref),
           metadata: value(attrs, :metadata) || %{}
         }}
    end
  end

  @doc """
  Normalizes an EVM transaction request.
  """
  @spec transaction_request(map()) :: {:ok, map()} | {:error, String.t()}
  def transaction_request(attrs) when is_map(attrs) do
    from = value(attrs, :from)
    to = value(attrs, :to)
    chain_id = value(attrs, :chain_id)

    cond do
      not valid_address?(from) ->
        {:error, "Invalid transaction sender address"}

      not is_integer(chain_id) ->
        {:error, "Missing or invalid chain_id"}

      not is_nil(to) and not valid_address?(to) ->
        {:error, "Invalid transaction recipient address"}

      true ->
        {:ok,
         %{
           chain_id: chain_id,
           from: normalize_address(from),
           to: maybe_normalize_address(to),
           value: value(attrs, :value) || "0x0",
           data: value(attrs, :data) || "0x",
           nonce: value(attrs, :nonce),
           gas_limit: value(attrs, :gas_limit),
           max_fee_per_gas: value(attrs, :max_fee_per_gas),
           max_priority_fee_per_gas: value(attrs, :max_priority_fee_per_gas),
           idempotency_key: value(attrs, :idempotency_key)
         }}
    end
  end

  @doc """
  Builds a signer policy decision for a transaction request.
  """
  @spec authorize_transaction(map(), map()) :: map()
  def authorize_transaction(request, policy \\ %{}) when is_map(request) do
    max_value = value(policy, :max_value)
    allowed_chains = value(policy, :allowed_chains) || []
    value_amount = hex_or_integer(value(request, :value) || "0x0")

    cond do
      allowed_chains != [] and value(request, :chain_id) not in allowed_chains ->
        %{authorized?: false, reason: :chain_not_allowed}

      is_integer(max_value) and value_amount > max_value ->
        %{authorized?: false, reason: :value_limit_exceeded}

      true ->
        %{authorized?: true, reason: :allowed}
    end
  end

  @doc """
  Creates a queue item for the transaction lifecycle.
  """
  @spec queue_item(map(), map()) :: map()
  def queue_item(request, opts \\ %{}) do
    %{
      id: value(opts, :id) || "tx-#{:erlang.phash2(request)}",
      state: value(opts, :state) || :queued,
      request: request,
      attempts: value(opts, :attempts) || 0,
      max_attempts: value(opts, :max_attempts) || 3,
      created_at: value(opts, :created_at) || DateTime.utc_now(),
      updated_at: value(opts, :updated_at)
    }
  end

  @doc """
  Transitions a transaction queue item.
  """
  @spec transition(map(), atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def transition(item, state, attrs \\ %{}) when is_map(item) and state in @queue_states do
    {:ok,
     item
     |> Map.put(:state, state)
     |> Map.put(:updated_at, value(attrs, :updated_at) || DateTime.utc_now())
     |> put_optional(:tx_hash, value(attrs, :tx_hash))
     |> put_optional(:receipt, value(attrs, :receipt))
     |> put_optional(:error, value(attrs, :error))}
  end

  def transition(_item, state, _attrs), do: {:error, "Unsupported transaction queue state: #{state}"}

  @doc """
  Builds an offline signing plan for an external signer.
  """
  @spec signing_plan(map(), map()) :: map()
  def signing_plan(request, wallet) do
    %{
      signer_ref: value(wallet, :signer_ref),
      wallet_type: value(wallet, :type),
      address: value(wallet, :address),
      chain_id: value(request, :chain_id),
      payload: request,
      requires_private_key?: false,
      next_step: :send_to_signer
    }
  end

  @doc """
  Builds a broadcast plan for a signed raw transaction.
  """
  @spec broadcast_plan(integer(), String.t(), map()) :: map()
  def broadcast_plan(chain_id, raw_transaction, opts \\ %{}) when is_integer(chain_id) and is_binary(raw_transaction) do
    %{
      chain_id: chain_id,
      method: "eth_sendRawTransaction",
      params: [raw_transaction],
      idempotency_key: value(opts, :idempotency_key)
    }
  end

  @doc """
  Normalizes balance snapshots across chains.
  """
  @spec balance_snapshot(map()) :: map()
  def balance_snapshot(attrs) when is_map(attrs) do
    %{
      wallet_id: value(attrs, :wallet_id),
      address: attrs |> value(:address) |> maybe_normalize_address(),
      chain_id: value(attrs, :chain_id),
      asset: value(attrs, :asset) || :native,
      balance: value(attrs, :balance) || "0x0",
      captured_at: value(attrs, :captured_at) || DateTime.utc_now()
    }
  end

  @doc """
  Builds transaction history entries for monitoring.
  """
  @spec history_entry(map()) :: map()
  def history_entry(attrs) when is_map(attrs) do
    %{
      tx_hash: value(attrs, :tx_hash),
      chain_id: value(attrs, :chain_id),
      from: attrs |> value(:from) |> maybe_normalize_address(),
      to: attrs |> value(:to) |> maybe_normalize_address(),
      status: value(attrs, :status) || :pending,
      block_number: value(attrs, :block_number),
      gas_used: value(attrs, :gas_used),
      effective_gas_price: value(attrs, :effective_gas_price),
      observed_at: value(attrs, :observed_at) || DateTime.utc_now()
    }
  end

  defp valid_address?(address) when is_binary(address), do: Regex.match?(~r/^0x[0-9a-fA-F]{40}$/, address)
  defp valid_address?(_address), do: false

  defp normalize_address(address), do: String.downcase(address)
  defp maybe_normalize_address(nil), do: nil
  defp maybe_normalize_address(address) when is_binary(address), do: normalize_address(address)

  defp hex_or_integer(value) when is_integer(value), do: value

  defp hex_or_integer("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {parsed, _rest} -> parsed
      :error -> 0
    end
  end

  defp hex_or_integer(_value), do: 0

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
