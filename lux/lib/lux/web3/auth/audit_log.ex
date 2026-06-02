defmodule Lux.Web3.Auth.AuditLog do
  @moduledoc """
  Audit logging for Web3 authentication events.

  Tracks all authentication attempts, session lifecycle events,
  role changes, and permission checks for compliance and security
  monitoring. Logs are persisted to ETS with configurable TTL.
  """

  require Logger

  @typedoc "Audit log entry"
  @type entry :: %{
          required(:id) => String.t(),
          required(:timestamp) => DateTime.t(),
          required(:event) => atom(),
          required(:address) => String.t() | nil,
          optional(:details) => map(),
          optional(:ip_address) => String.t() | nil,
          optional(:user_agent) => String.t() | nil
        }

  @ets_table :lux_web3_audit_log
  @max_entries 100_000

  @doc """
  Initializes the audit log ETS store.
  """
  @spec init_store() :: :ok
  def init_store do
    unless :ets.whereis(@ets_table) != :undefined do
      :ets.new(@ets_table, [
        :named_table,
        :public,
        :ordered_set,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    :ok
  end

  @doc """
  Records an authentication event in the audit log.

  Returns `{:ok, entry_id}` on success.
  """
  @spec log_auth_success(String.t(), map()) :: {:ok, String.t()}
  def log_auth_success(address, details \\ %{}) do
    log_event(:auth_success, address, details)
  end

  @doc """
  Records a failed authentication attempt.
  """
  @spec log_auth_failure(String.t() | nil, String.t(), map()) :: {:ok, String.t()}
  def log_auth_failure(address, reason, details \\ %{}) do
    log_event(:auth_failure, address, Map.put(details, :reason, reason))
  end

  @doc """
  Records a session creation event.
  """
  @spec log_session_created(String.t(), String.t(), map()) :: {:ok, String.t()}
  def log_session_created(address, session_id, details \\ %{}) do
    log_event(:session_created, address, Map.put(details, :session_id, session_id))
  end

  @doc """
  Records a session expiration or deletion.
  """
  @spec log_session_expired(String.t(), String.t(), map()) :: {:ok, String.t()}
  def log_session_expired(address, session_id, details \\ %{}) do
    log_event(:session_expired, address, Map.put(details, :session_id, session_id))
  end

  @doc """
  Records a role assignment change.
  """
  @spec log_role_change(String.t(), String.t(), atom(), atom(), map()) :: {:ok, String.t()}
  def log_role_change(actor_address, target_address, role, action \\ :assigned, details \\ %{}) do
    log_event(:role_change, target_address, %{
      actor: actor_address,
      role: role,
      action: action
    } |> Map.merge(details))
  end

  @doc """
  Records a signature verification event.
  """
  @spec log_signature_verification(String.t(), boolean(), map()) :: {:ok, String.t()}
  def log_signature_verification(address, success, details \\ %{}) do
    event = if success, do: :signature_verified, else: :signature_invalid
    log_event(event, address, details)
  end

  @doc """
  Queries audit log entries for a specific address.
  """
  @spec query_by_address(String.t(), keyword()) :: [entry()]
  def query_by_address(address, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    addr = String.downcase(address)

    @ets_table
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, entry} -> entry.address == addr end)
    |> Enum.sort_by(fn {id, _entry} -> id end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {_id, entry} -> entry end)
  end

  @doc """
  Queries audit log entries by event type.
  """
  @spec query_by_event(atom(), keyword()) :: [entry()]
  def query_by_event(event, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    @ets_table
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, entry} -> entry.event == event end)
    |> Enum.sort_by(fn {id, _entry} -> id end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {_id, entry} -> entry end)
  end

  @doc """
  Queries audit log entries within a time range.
  """
  @spec query_by_time(DateTime.t(), DateTime.t(), keyword()) :: [entry()]
  def query_by_time(from, to, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    @ets_table
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, entry} ->
      DateTime.compare(entry.timestamp, from) != :lt and
        DateTime.compare(entry.timestamp, to) != :gt
    end)
    |> Enum.sort_by(fn {id, _entry} -> id end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {_id, entry} -> entry end)
  end

  @doc """
  Returns total count of audit log entries.
  """
  @spec count() :: non_neg_integer()
  def count do
    :ets.info(@ets_table, :size)
  end

  @doc """
  Returns count of entries for a specific event type.
  """
  @spec count_by_event(atom()) :: non_neg_integer()
  def count_by_event(event) do
    @ets_table
    |> :ets.tab2list()
    |> Enum.count(fn {_id, entry} -> entry.event == event end)
  end

  @doc """
  Cleans up old entries beyond the max capacity.
  """
  @spec cleanup() :: non_neg_integer()
  def cleanup do
    size = :ets.info(@ets_table, :size)

    if size > @max_entries do
      to_delete = size - @max_entries

      @ets_table
      |> :ets.tab2list()
      |> Enum.sort_by(fn {id, _entry} -> id end)
      |> Enum.take(to_delete)
      |> Enum.each(fn {id, _entry} -> :ets.delete(@ets_table, id) end)

      to_delete
    else
      0
    end
  end

  defp log_event(event, address, details) do
    id = "#{System.system_time(:millisecond)}_#{:rand.uniform(1_000_000)}"
    entry_id = String.to_atom(id)

    entry = %{
      id: id,
      timestamp: DateTime.utc_now(),
      event: event,
      address: address && String.downcase(address),
      details: details
    }

    :ets.insert(@ets_table, {entry_id, entry})
    trim_if_needed()

    {:ok, id}
  end

  defp trim_if_needed do
    size = :ets.info(@ets_table, :size)

    if size > @max_entries + 1000 do
      to_delete = div(@max_entries, 10)

      @ets_table
      |> :ets.tab2list()
      |> Enum.sort_by(fn {id, _entry} -> id end)
      |> Enum.take(to_delete)
      |> Enum.each(fn {id, _entry} -> :ets.delete(@ets_table, id) end)
    end

    :ok
  end
end
