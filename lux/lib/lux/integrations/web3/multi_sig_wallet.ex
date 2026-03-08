defmodule Lux.Integrations.Web3.MultiSigWallet do
  @moduledoc """
  Multi-signature wallet implementation for Lux.

  Supports M-of-N signature schemes where M signers must approve
  a transaction before it can be submitted.
  """

  defstruct [:name, :signers, :threshold, :pending_txs, :executed_txs, :nonce]

  @doc "Create a new multi-sig wallet."
  def new(name, signers, threshold) when threshold > 0 and threshold <= length(signers) do
    {:ok, %__MODULE__{
      name: name,
      signers: MapSet.new(signers),
      threshold: threshold,
      pending_txs: %{},
      executed_txs: [],
      nonce: 0
    }}
  end

  def new(_name, _signers, _threshold), do: {:error, :invalid_threshold}

  @doc "Propose a new transaction. Must be from an authorized signer."
  def propose(%__MODULE__{} = wallet, signer, tx_params) do
    if MapSet.member?(wallet.signers, signer) do
      tx_id = wallet.nonce
      pending_tx = %{
        id: tx_id,
        params: tx_params,
        proposed_by: signer,
        signatures: MapSet.new([signer]),
        proposed_at: DateTime.utc_now(),
        status: :pending
      }

      wallet = %{wallet |
        pending_txs: Map.put(wallet.pending_txs, tx_id, pending_tx),
        nonce: wallet.nonce + 1
      }

      {:ok, tx_id, wallet}
    else
      {:error, :unauthorized_signer}
    end
  end

  @doc "Approve (sign) a pending transaction."
  def approve(%__MODULE__{} = wallet, tx_id, signer) do
    with true <- MapSet.member?(wallet.signers, signer),
         %{} = tx <- Map.get(wallet.pending_txs, tx_id),
         false <- tx.status == :executed do
      tx = %{tx | signatures: MapSet.put(tx.signatures, signer)}

      if MapSet.size(tx.signatures) >= wallet.threshold do
        tx = %{tx | status: :ready}
        wallet = %{wallet | pending_txs: Map.put(wallet.pending_txs, tx_id, tx)}
        {:ok, :ready, wallet}
      else
        wallet = %{wallet | pending_txs: Map.put(wallet.pending_txs, tx_id, tx)}
        remaining = wallet.threshold - MapSet.size(tx.signatures)
        {:ok, {:pending, remaining}, wallet}
      end
    else
      false -> {:error, :unauthorized_signer}
      nil -> {:error, :tx_not_found}
      true -> {:error, :already_executed}
    end
  end

  @doc "Execute a ready transaction (must have enough signatures)."
  def execute(%__MODULE__{} = wallet, tx_id) do
    case Map.get(wallet.pending_txs, tx_id) do
      nil -> {:error, :tx_not_found}
      %{status: :executed} -> {:error, :already_executed}
      %{status: :ready} = tx ->
        tx = %{tx | status: :executed}
        wallet = %{wallet |
          pending_txs: Map.delete(wallet.pending_txs, tx_id),
          executed_txs: [tx | wallet.executed_txs]
        }
        {:ok, tx, wallet}
      %{signatures: sigs} ->
        {:error, {:insufficient_signatures, MapSet.size(sigs), wallet.threshold}}
    end
  end

  @doc "Reject a pending transaction."
  def reject(%__MODULE__{} = wallet, tx_id, signer) do
    if MapSet.member?(wallet.signers, signer) do
      case Map.get(wallet.pending_txs, tx_id) do
        nil -> {:error, :tx_not_found}
        _tx ->
          wallet = %{wallet | pending_txs: Map.delete(wallet.pending_txs, tx_id)}
          {:ok, wallet}
      end
    else
      {:error, :unauthorized_signer}
    end
  end

  @doc "Get transaction status."
  def tx_status(%__MODULE__{} = wallet, tx_id) do
    case Map.get(wallet.pending_txs, tx_id) do
      nil ->
        case Enum.find(wallet.executed_txs, &(&1.id == tx_id)) do
          nil -> {:error, :not_found}
          tx -> {:ok, tx}
        end
      tx -> {:ok, tx}
    end
  end

  @doc "List pending transactions."
  def pending(%__MODULE__{} = wallet) do
    Map.values(wallet.pending_txs)
  end

  @doc "Get wallet info."
  def info(%__MODULE__{} = wallet) do
    %{
      name: wallet.name,
      signers: MapSet.to_list(wallet.signers),
      threshold: wallet.threshold,
      pending_count: map_size(wallet.pending_txs),
      executed_count: length(wallet.executed_txs),
      nonce: wallet.nonce
    }
  end
end
