defmodule Lux.Web3.Auth.SessionManager do
  @moduledoc """
  Manages authenticated Web3 sessions with expiry and refresh.

  Features:
  - Create sessions after SIWE verification
  - Automatic expiry
  - Session refresh
  - Audit logging of auth events
  """

  use GenServer

  defstruct [:sessions, :audit_log, :default_ttl, :max_sessions]

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def create_session(pid \\ __MODULE__, address, metadata \\ %{}) do
    GenServer.call(pid, {:create_session, String.downcase(address), metadata})
  end

  def get_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:get_session, session_id})
  end

  def validate_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:validate_session, session_id})
  end

  def refresh_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:refresh_session, session_id})
  end

  def revoke_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:revoke_session, session_id})
  end

  def revoke_all(pid \\ __MODULE__, address) do
    GenServer.call(pid, {:revoke_all, String.downcase(address)})
  end

  def get_audit_log(pid \\ __MODULE__, opts \\ %{}) do
    GenServer.call(pid, {:get_audit_log, opts})
  end

  def active_sessions(pid \\ __MODULE__) do
    GenServer.call(pid, :active_sessions)
  end

  # Server

  @impl true
  def init(opts) do
    state = %__MODULE__{
      sessions: %{},
      audit_log: [],
      default_ttl: opts[:default_ttl] || 3600,
      max_sessions: opts[:max_sessions] || 100
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:create_session, address, metadata}, _from, state) do
    session_id = generate_session_id()
    now = System.system_time(:second)

    session = %{
      id: session_id,
      address: address,
      created_at: now,
      expires_at: now + state.default_ttl,
      last_active: now,
      metadata: metadata
    }

    sessions = Map.put(state.sessions, session_id, session)
    log_entry = %{event: :session_created, address: address, session_id: session_id, at: now}

    {:reply, {:ok, session},
     %{state | sessions: sessions, audit_log: [log_entry | state.audit_log]}}
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil -> {:reply, {:error, :not_found}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  @impl true
  def handle_call({:validate_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      session ->
        now = System.system_time(:second)
        if session.expires_at > now do
          updated = %{session | last_active: now}
          {:reply, {:ok, updated}, %{state | sessions: Map.put(state.sessions, session_id, updated)}}
        else
          sessions = Map.delete(state.sessions, session_id)
          log_entry = %{event: :session_expired, session_id: session_id, at: now}
          {:reply, {:error, :expired}, %{state | sessions: sessions, audit_log: [log_entry | state.audit_log]}}
        end
    end
  end

  @impl true
  def handle_call({:refresh_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      session ->
        now = System.system_time(:second)
        if session.expires_at > now do
          updated = %{session | expires_at: now + state.default_ttl, last_active: now}
          {:reply, {:ok, updated}, %{state | sessions: Map.put(state.sessions, session_id, updated)}}
        else
          {:reply, {:error, :expired}, state}
        end
    end
  end

  @impl true
  def handle_call({:revoke_session, session_id}, _from, state) do
    now = System.system_time(:second)
    sessions = Map.delete(state.sessions, session_id)
    log_entry = %{event: :session_revoked, session_id: session_id, at: now}
    {:reply, :ok, %{state | sessions: sessions, audit_log: [log_entry | state.audit_log]}}
  end

  @impl true
  def handle_call({:revoke_all, address}, _from, state) do
    now = System.system_time(:second)
    {revoked, kept} = Enum.split_with(state.sessions, fn {_, s} -> s.address == address end)
    log_entry = %{event: :all_sessions_revoked, address: address, count: length(revoked), at: now}
    {:reply, {:ok, length(revoked)}, %{state | sessions: Map.new(kept), audit_log: [log_entry | state.audit_log]}}
  end

  @impl true
  def handle_call({:get_audit_log, opts}, _from, state) do
    logs = state.audit_log
    logs = if opts[:address], do: Enum.filter(logs, &(&1[:address] == opts[:address])), else: logs
    logs = Enum.take(logs, opts[:limit] || 50)
    {:reply, {:ok, logs}, state}
  end

  @impl true
  def handle_call(:active_sessions, _from, state) do
    now = System.system_time(:second)
    active = state.sessions
    |> Enum.filter(fn {_, s} -> s.expires_at > now end)
    |> Enum.map(fn {_, s} -> s end)
    {:reply, {:ok, active}, state}
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
  end
end
