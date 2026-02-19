defmodule Lux.Web3.Auth.AuditLog do
  @moduledoc """
  Audit logging for Web3 authentication and authorization events.

  Provides an append-only event log for security-relevant actions including:
  - Authentication attempts (success and failure)
  - Session creation, refresh, and revocation
  - Role assignments and permission checks
  - Token gate evaluations

  ## Architecture

  Uses an ETS table as an in-memory ring buffer with configurable max size.
  Events are timestamped and tagged with the relevant address and action type.
  The log can be queried by address, action type, or time range.

  ## Event Types

    * `:auth_success` - Successful authentication
    * `:auth_failure` - Failed authentication attempt
    * `:session_created` - New session created
    * `:session_refreshed` - Session TTL extended
    * `:session_revoked` - Session explicitly revoked
    * `:session_expired` - Session expired
    * `:role_assigned` - Role assigned to address
    * `:role_revoked` - Role removed from address
    * `:permission_granted` - Permission check passed
    * `:permission_denied` - Permission check failed
    * `:token_gate_passed` - Token gate requirement met
    * `:token_gate_failed` - Token gate requirement not met

  ## Examples

      iex> AuditLog.log(:auth_success, "0x71C7...", %{chain_id: 1, method: :siwe})
      :ok
      iex> AuditLog.query(address: "0x71C7...")
      [%{action: :auth_success, address: "0x71C7...", ...}]
  """

  use GenServer

  require Logger

  @type action ::
          :auth_success
          | :auth_failure
          | :session_created
          | :session_refreshed
          | :session_revoked
          | :session_expired
          | :role_assigned
          | :role_revoked
          | :permission_granted
          | :permission_denied
          | :token_gate_passed
          | :token_gate_failed

  @type event :: %{
          id: String.t(),
          action: action(),
          address: String.t(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  @default_max_events 10_000
  @table_name :lux_web3_audit_log

  # Client API

  @doc """
  Starts the audit log service.

  ## Options

    * `:name` - GenServer name (defaults to `#{__MODULE__}`)
    * `:max_events` - Maximum events to retain (defaults to #{@default_max_events})
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Logs an audit event.

  ## Parameters

    * `action` - The action type atom
    * `address` - The wallet address involved
    * `metadata` - Additional event data (optional)
  """
  @spec log(action(), String.t(), map(), atom()) :: :ok
  def log(action, address, metadata \\ %{}, server \\ __MODULE__) do
    GenServer.cast(server, {:log, action, address, metadata})
  end

  @doc """
  Queries the audit log with optional filters.

  ## Filter Options

    * `:address` - Filter by wallet address
    * `:action` - Filter by action type
    * `:since` - Only events after this DateTime
    * `:until` - Only events before this DateTime
    * `:limit` - Maximum number of events to return (defaults to 100)

  ## Returns

    List of matching events, most recent first.
  """
  @spec query(keyword(), atom()) :: [event()]
  def query(filters \\ [], server \\ __MODULE__) do
    GenServer.call(server, {:query, filters})
  end

  @doc """
  Returns a count of events matching the given filters.
  """
  @spec count(keyword(), atom()) :: non_neg_integer()
  def count(filters \\ [], server \\ __MODULE__) do
    GenServer.call(server, {:count, filters})
  end

  @doc """
  Clears all audit log entries.

  Use with caution — primarily for testing.
  """
  @spec clear(atom()) :: :ok
  def clear(server \\ __MODULE__) do
    GenServer.call(server, :clear)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    table = Keyword.get(opts, :table_name, @table_name)
    max_events = Keyword.get(opts, :max_events, @default_max_events)

    ^table =
      :ets.new(table, [:named_table, :ordered_set, :public, read_concurrency: true])

    {:ok, %{table: table, max_events: max_events, counter: 0}}
  end

  @impl true
  def handle_cast({:log, action, address, metadata}, state) do
    event = %{
      id: Lux.UUID.generate(),
      action: action,
      address: String.downcase(address),
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }

    counter = state.counter + 1
    :ets.insert(state.table, {counter, event})

    # Trim old events if over limit
    state =
      if counter > state.max_events do
        trim_key = counter - state.max_events
        :ets.select_delete(state.table, [{{:"$1", :_}, [{:"=<", :"$1", trim_key}], [true]}])
        %{state | counter: counter}
      else
        %{state | counter: counter}
      end

    {:noreply, state}
  end

  @impl true
  def handle_call({:query, filters}, _from, state) do
    limit = Keyword.get(filters, :limit, 100)

    events =
      state.table
      |> :ets.tab2list()
      |> Enum.map(fn {_key, event} -> event end)
      |> apply_filters(filters)
      |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
      |> Enum.take(limit)

    {:reply, events, state}
  end

  @impl true
  def handle_call({:count, filters}, _from, state) do
    count =
      state.table
      |> :ets.tab2list()
      |> Enum.map(fn {_key, event} -> event end)
      |> apply_filters(filters)
      |> length()

    {:reply, count, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.table)
    {:reply, :ok, %{state | counter: 0}}
  end

  # Private helpers

  defp apply_filters(events, filters) do
    events
    |> filter_by_address(Keyword.get(filters, :address))
    |> filter_by_action(Keyword.get(filters, :action))
    |> filter_by_since(Keyword.get(filters, :since))
    |> filter_by_until(Keyword.get(filters, :until))
  end

  defp filter_by_address(events, nil), do: events

  defp filter_by_address(events, address) do
    normalized = String.downcase(address)
    Enum.filter(events, &(&1.address == normalized))
  end

  defp filter_by_action(events, nil), do: events
  defp filter_by_action(events, action), do: Enum.filter(events, &(&1.action == action))

  defp filter_by_since(events, nil), do: events

  defp filter_by_since(events, since) do
    Enum.filter(events, fn e -> DateTime.compare(e.timestamp, since) != :lt end)
  end

  defp filter_by_until(events, nil), do: events

  defp filter_by_until(events, until_dt) do
    Enum.filter(events, fn e -> DateTime.compare(e.timestamp, until_dt) != :gt end)
  end
end
