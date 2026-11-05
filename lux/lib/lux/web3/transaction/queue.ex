defmodule Lux.Web3.Transaction.Queue do
  @moduledoc """
  In-memory transaction queue with atomic per-account nonce management.

  Each `(account, chain_id)` pair tracks the next expected nonce together with
  the set of nonces that are currently pending. Submissions are serialised by
  the `GenServer`, which guarantees that:

    * a nonce below the expected nonce is rejected (`:nonce_too_low`)
    * a nonce already pending is rejected (`:duplicate_nonce`), preventing
      double-spends
    * a valid nonce is queued and later advanced by `confirm/2`

  ## Examples

      iex> {:ok, queue} = Lux.Web3.Transaction.Queue.start_link()
      iex> {:ok, tx} = Lux.Web3.Transaction.build(%{
      ...>   chain_id: 1, nonce: 0, to: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
      ...> })
      iex> {:ok, id} = Lux.Web3.Transaction.Queue.submit(queue, "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", tx)
      iex> Lux.Web3.Transaction.Queue.submit(queue, "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", tx)
      {:error, :duplicate_nonce}
      iex> match?({:ok, %{status: :confirmed}}, Lux.Web3.Transaction.Queue.confirm(queue, id))
      true
  """

  use GenServer

  alias Ethers.Utils

  @type status :: :pending | :confirmed | :failed

  @type entry :: %{
          id: String.t(),
          account: String.t(),
          chain_id: non_neg_integer(),
          nonce: non_neg_integer(),
          transaction: struct(),
          status: status()
        }

  @type state :: %{
          entries: %{String.t() => entry()},
          order: [String.t()],
          next_nonce: %{{String.t(), non_neg_integer()} => non_neg_integer()},
          pending_nonces: %{{String.t(), non_neg_integer()} => MapSet.t()}
        }

  @doc """
  Starts the transaction queue.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    case Keyword.get(opts, :name) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  @doc """
  Child spec for supervision trees.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  @doc """
  Submits a transaction for `account`.
  """
  @spec submit(GenServer.server(), term(), term()) :: {:ok, String.t()} | {:error, atom()}
  def submit(server, account, transaction) do
    GenServer.call(server, {:submit, account, transaction})
  end

  @doc """
  Returns the next expected nonce for an account on a chain.
  """
  @spec next_nonce(GenServer.server(), term(), term()) ::
          {:ok, non_neg_integer()} | {:error, atom()}
  def next_nonce(server, account, chain_id) do
    GenServer.call(server, {:next_nonce, account, chain_id})
  end

  @doc """
  Marks a queued transaction as confirmed and advances the expected nonce.
  """
  @spec confirm(GenServer.server(), String.t()) :: {:ok, entry()} | {:error, atom()}
  def confirm(server, id), do: GenServer.call(server, {:confirm, id})

  @doc """
  Marks a queued transaction as failed, releasing its nonce for retry.
  """
  @spec fail(GenServer.server(), String.t()) :: {:ok, entry()} | {:error, atom()}
  def fail(server, id), do: GenServer.call(server, {:fail, id})

  @doc """
  Fetches a queued transaction by id.
  """
  @spec get(GenServer.server(), String.t()) :: {:ok, entry()} | {:error, :unknown_transaction}
  def get(server, id), do: GenServer.call(server, {:get, id})

  @doc """
  Lists pending transactions, optionally filtered by account.
  """
  @spec pending(GenServer.server()) :: [entry()]
  def pending(server), do: GenServer.call(server, :pending)

  @spec pending(GenServer.server(), term()) :: [entry()]
  def pending(server, account), do: GenServer.call(server, {:pending, account})

  @impl true
  def init(_opts) do
    {:ok, %{entries: %{}, order: [], next_nonce: %{}, pending_nonces: %{}}}
  end

  @impl true
  def handle_call({:submit, account, transaction}, _from, state) do
    with {:ok, account} <- normalize_account(account),
         {:ok, chain_id, nonce} <- tx_identity(transaction) do
      key = {account, chain_id}
      expected = Map.get(state.next_nonce, key, 0)
      pending = Map.get(state.pending_nonces, key, MapSet.new())

      case classify(nonce, expected, pending) do
        :ok -> enqueue(state, account, chain_id, nonce, transaction)
        {:error, reason} -> {:reply, {:error, reason}, state}
      end
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:next_nonce, account, chain_id}, _from, state) do
    with {:ok, account} <- normalize_account(account),
         {:ok, chain} <- normalize_chain_id(chain_id) do
      {:reply, {:ok, Map.get(state.next_nonce, {account, chain}, 0)}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:confirm, id}, _from, state) do
    case fetch_pending(state, id) do
      {:ok, entry} ->
        key = {entry.account, entry.chain_id}

        new_state =
          state
          |> put_entry(%{entry | status: :confirmed})
          |> release_nonce(key, entry.nonce)
          |> advance_nonce(key, entry.nonce)

        {:reply, {:ok, Map.fetch!(new_state.entries, id)}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:fail, id}, _from, state) do
    case fetch_pending(state, id) do
      {:ok, entry} ->
        key = {entry.account, entry.chain_id}

        new_state =
          state |> put_entry(%{entry | status: :failed}) |> release_nonce(key, entry.nonce)

        {:reply, {:ok, Map.fetch!(new_state.entries, id)}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get, id}, _from, state) do
    case Map.fetch(state.entries, id) do
      {:ok, entry} -> {:reply, {:ok, entry}, state}
      :error -> {:reply, {:error, :unknown_transaction}, state}
    end
  end

  def handle_call(:pending, _from, state) do
    {:reply, pending_entries(state, nil), state}
  end

  def handle_call({:pending, account}, _from, state) do
    case normalize_account(account) do
      {:ok, account} -> {:reply, pending_entries(state, account), state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp enqueue(state, account, chain_id, nonce, transaction) do
    id = generate_id()
    key = {account, chain_id}

    entry = %{
      id: id,
      account: account,
      chain_id: chain_id,
      nonce: nonce,
      transaction: transaction,
      status: :pending
    }

    new_state =
      state
      |> put_in([:entries, id], entry)
      |> put_in([:order], [id | state.order])
      |> put_in(
        [:pending_nonces, key],
        MapSet.put(Map.get(state.pending_nonces, key, MapSet.new()), nonce)
      )

    {:reply, {:ok, id}, new_state}
  end

  defp classify(nonce, expected, pending) do
    cond do
      nonce < expected -> {:error, :nonce_too_low}
      MapSet.member?(pending, nonce) -> {:error, :duplicate_nonce}
      true -> :ok
    end
  end

  defp fetch_pending(state, id) do
    case Map.fetch(state.entries, id) do
      {:ok, %{status: :pending} = entry} -> {:ok, entry}
      {:ok, _entry} -> {:error, :not_pending}
      :error -> {:error, :unknown_transaction}
    end
  end

  defp put_entry(state, entry), do: put_in(state, [:entries, entry.id], entry)

  defp release_nonce(state, key, nonce) do
    pending = Map.get(state.pending_nonces, key, MapSet.new())
    put_in(state, [:pending_nonces, key], MapSet.delete(pending, nonce))
  end

  defp advance_nonce(state, key, nonce) do
    expected = Map.get(state.next_nonce, key, 0)

    if nonce >= expected do
      put_in(state, [:next_nonce, key], nonce + 1)
    else
      state
    end
  end

  defp pending_entries(state, account) do
    state.order
    |> Enum.reverse()
    |> Enum.map(&Map.fetch!(state.entries, &1))
    |> Enum.filter(fn entry ->
      entry.status == :pending and (is_nil(account) or entry.account == account)
    end)
  end

  defp normalize_account(account) when is_binary(account) do
    case Utils.decode_address(String.trim(account)) do
      {:ok, decoded} -> {:ok, Utils.encode_address!(decoded)}
      {:error, _reason} -> {:error, :invalid_account}
    end
  end

  defp normalize_account(_account), do: {:error, :invalid_account}

  defp normalize_chain_id(chain_id) when is_integer(chain_id) and chain_id >= 0,
    do: {:ok, chain_id}

  defp normalize_chain_id(_chain_id), do: {:error, :invalid_chain_id}

  defp tx_identity(%{chain_id: chain_id, nonce: nonce})
       when is_integer(chain_id) and is_integer(nonce) and nonce >= 0 do
    {:ok, chain_id, nonce}
  end

  defp tx_identity(_transaction), do: {:error, :invalid_transaction}

  defp generate_id, do: "0x" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
end
