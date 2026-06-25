defmodule Lux.Web3.Session.Manager do
  @moduledoc """
  Session management for authenticated Ethereum addresses.

  Tracks active sessions with expiry, supports revocation,
  and maintains session metadata for auditing.
  """

  use GenServer

  alias Lux.Web3.Schemas.AuditLog

  # Client API

  @doc """
  Start the session manager server.
  """
  @spec start_link(list()) :: GenServer.on_start()
  def start_link(opts \ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Create a new session for an address.
  """
  @spec create_session(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  def create_session(address, metadata \ %{}) do
    GenServer.call(__MODULE__, {:create, String.downcase(address), metadata})
  end

  @doc """
  Get session details by session ID.
  """
  @spec get_session(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get, session_id})
  end

  @doc """
  Get all active sessions for an address.
  """
  @spec get_sessions(String.t()) :: [map()]
  def get_sessions(address) do
    GenServer.call(__MODULE__, {:list, String.downcase(address)})
  end

  @doc """
  Revoke a session by ID.
  """
  @spec revoke_session(String.t()) :: :ok | {:error, :not_found}
  def revoke_session(session_id) do
    GenServer.call(__MODULE__, {:revoke, session_id})
  end

  @doc """
  Revoke all sessions for an address.
  """
  @spec revoke_all_sessions(String.t()) :: :ok
  def revoke_all_sessions(address) do
    GenServer.call(__MODULE__, {:revoke_all, String.downcase(address)})
  end

  @doc """
  Check if a session is still valid (not expired, not revoked).
  """
  @spec is_session_valid?(String.t()) :: boolean()
  def is_session_valid?(session_id) do
    case get_session(session_id) do
      {:ok, session} -> session[:valid] == true
      _ -> false
    end
  end

  # Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{sessions: %{}}}
  end

  @impl true
  def handle_call({:create, address, metadata}, _from, state) do
    session_id = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)

    expires_in = metadata[:ttl_seconds] || 3600
    expires_at = DateTime.utc_now() |> DateTime.add(expires_in, :second)

    session = %{
      id: session_id,
      address: address,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      expires_at: expires_at |> DateTime.to_iso8601(),
      metadata: metadata,
      valid: true
    }

    AuditLog.create(:session_created, address, %{
      session_id: session_id,
      ttl_seconds: expires_in
    })

    new_sessions = Map.put(state.sessions, session_id, session)
    {:reply, {:ok, session_id}, %{state | sessions: new_sessions}}
  end

  def handle_call({:get, session_id}, _from, state) do
    case state.sessions[session_id] do
      nil ->
        {:reply, {:error, :not_found}, state}

      session ->
        expired = DateTime.parse(session[:expires_at]) |> elem(0) |> maybe_before_now?()
        valid = session[:valid] && !expired

        session = Map.put(session, :valid, valid)
        {:reply, {:ok, session}, state}
    end
  end

  def handle_call({:list, address}, _from, state) do
    sessions =
      state.sessions
      |> Map.values()
      |> Enum.filter(&(&1[:address] == address))
      |> Enum.filter(fn s ->
        not (DateTime.parse(s[:expires_at]) |> elem(0) |> maybe_before_now?())
      end)

    {:reply, sessions, state}
  end

  def handle_call({:revoke, session_id}, _from, state) do
    case state.sessions[session_id] do
      nil ->
        {:reply, {:error, :not_found}, state}

      session ->
        AuditLog.create(:session_revoked, session[:address], %{session_id: session_id})
        new_sessions = Map.delete(state.sessions, session_id)
        {:reply, :ok, %{state | sessions: new_sessions}}
    end
  end

  def handle_call({:revoke_all, address}, _from, state) do
    to_remove =
      state.sessions
      |> Map.keys()
      |> Enum.filter(fn id -> state.sessions[id][:address] == address end)

    Enum.each(to_remove, fn id ->
      AuditLog.create(:session_revoked, address, %{session_id: id, reason: :bulk_revoke})
    end)

    new_sessions = Map.drop(state.sessions, to_remove)
    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  def handle_info(:cleanup_expired, state) do
    expired_ids =
      state.sessions
      |> Enum.filter(fn {_id, session} ->
        DateTime.parse(session[:expires_at])
        |> elem(0)
        |> maybe_before_now?()
      end)
      |> Enum.map(&elem(&1, 0))

    Enum.each(expired_ids, fn id ->
      session = state.sessions[id]
      AuditLog.create(:session_expired, session[:address], %{session_id: id})
    end)

    new_sessions = Map.drop(state.sessions, expired_ids)
    {:noreply, %{state | sessions: new_sessions}}
  end

  # Helpers

  defp maybe_before_now?(nil), do: false

  defp maybe_before_now?({%DateTime{} = dt, _}), do: DateTime.compare(dt, DateTime.utc_now()) == :lt
end
