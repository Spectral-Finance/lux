defmodule Lux.Web3.Auth.Session do
  @moduledoc """
  Manages authenticated Web3 sessions with automatic expiry.

  Uses an ETS-based session store for fast lookups and automatic cleanup.
  Sessions are created after successful SIWE authentication and can be
  refreshed, validated, or revoked.

  ## Architecture

  Sessions are stored in an ETS table with the session token as key.
  A periodic cleanup process removes expired sessions. Each session tracks:

  - The authenticated wallet address
  - Chain ID for multi-chain support
  - Creation and expiry times
  - Associated roles for RBAC integration
  - Arbitrary metadata

  ## Examples

      iex> {:ok, session} = Session.create(%{
      ...>   address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F",
      ...>   chain_id: 1,
      ...>   ttl: 3600
      ...> })
      iex> {:ok, _session} = Session.get(session.token)
      iex> Session.revoke(session.token)
      :ok
  """

  use GenServer

  require Logger

  @type session_data :: %{
          token: String.t(),
          address: String.t(),
          chain_id: pos_integer(),
          roles: [String.t()],
          created_at: DateTime.t(),
          expires_at: DateTime.t(),
          metadata: map()
        }

  @default_ttl 3600
  @cleanup_interval :timer.minutes(5)
  @token_bytes 32
  @table_name :lux_web3_sessions

  # Client API

  @doc """
  Starts the session manager.

  ## Options

    * `:name` - The GenServer name (defaults to `#{__MODULE__}`)
    * `:cleanup_interval` - How often to clean up expired sessions in ms
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Creates a new session for an authenticated wallet.

  ## Parameters

    * `attrs` - Map with session attributes:
      * `:address` (required) - The authenticated wallet address
      * `:chain_id` (required) - The chain ID
      * `:roles` - List of role strings (defaults to `[]`)
      * `:ttl` - Time to live in seconds (defaults to #{@default_ttl})
      * `:metadata` - Additional metadata map (defaults to `%{}`)

  ## Returns

    * `{:ok, session_data}` on success
    * `{:error, reason}` on failure
  """
  @spec create(map(), atom()) :: {:ok, session_data()} | {:error, String.t()}
  def create(attrs, server \\ __MODULE__) do
    GenServer.call(server, {:create, attrs})
  end

  @doc """
  Retrieves a session by its token.

  Returns `{:error, :expired}` if the session has expired and removes it.
  Returns `{:error, :not_found}` if no session exists with that token.
  """
  @spec get(String.t(), atom()) :: {:ok, session_data()} | {:error, :not_found | :expired}
  def get(token, server \\ __MODULE__) do
    GenServer.call(server, {:get, token})
  end

  @doc """
  Refreshes a session's expiry time.

  ## Parameters

    * `token` - The session token
    * `ttl` - New time to live in seconds (defaults to #{@default_ttl})
  """
  @spec refresh(String.t(), pos_integer(), atom()) ::
          {:ok, session_data()} | {:error, :not_found | :expired}
  def refresh(token, ttl \\ @default_ttl, server \\ __MODULE__) do
    GenServer.call(server, {:refresh, token, ttl})
  end

  @doc """
  Revokes (deletes) a session.
  """
  @spec revoke(String.t(), atom()) :: :ok
  def revoke(token, server \\ __MODULE__) do
    GenServer.call(server, {:revoke, token})
  end

  @doc """
  Revokes all sessions for a given address.
  """
  @spec revoke_all(String.t(), atom()) :: :ok
  def revoke_all(address, server \\ __MODULE__) do
    GenServer.call(server, {:revoke_all, address})
  end

  @doc """
  Lists all active sessions for an address.
  """
  @spec list_by_address(String.t(), atom()) :: [session_data()]
  def list_by_address(address, server \\ __MODULE__) do
    GenServer.call(server, {:list_by_address, address})
  end

  @doc """
  Updates the roles associated with a session.
  """
  @spec update_roles(String.t(), [String.t()], atom()) ::
          {:ok, session_data()} | {:error, :not_found | :expired}
  def update_roles(token, roles, server \\ __MODULE__) do
    GenServer.call(server, {:update_roles, token, roles})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    table = Keyword.get(opts, :table_name, @table_name)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @cleanup_interval)

    # Create ETS table for session storage
    ^table = :ets.new(table, [:named_table, :set, :public, read_concurrency: true])

    # Schedule periodic cleanup
    Process.send_after(self(), :cleanup, cleanup_interval)

    {:ok, %{table: table, cleanup_interval: cleanup_interval}}
  end

  @impl true
  def handle_call({:create, attrs}, _from, state) do
    with :ok <- validate_required(attrs, [:address, :chain_id]) do
      now = DateTime.utc_now()
      ttl = Map.get(attrs, :ttl, @default_ttl)

      session = %{
        token: generate_token(),
        address: attrs.address,
        chain_id: attrs.chain_id,
        roles: Map.get(attrs, :roles, []),
        created_at: now,
        expires_at: DateTime.add(now, ttl, :second),
        metadata: Map.get(attrs, :metadata, %{})
      }

      :ets.insert(state.table, {session.token, session})

      Logger.info("Web3 session created for #{attrs.address} on chain #{attrs.chain_id}")
      {:reply, {:ok, session}, state}
    else
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get, token}, _from, state) do
    result =
      case :ets.lookup(state.table, token) do
        [{^token, session}] ->
          if DateTime.compare(DateTime.utc_now(), session.expires_at) == :lt do
            {:ok, session}
          else
            :ets.delete(state.table, token)
            {:error, :expired}
          end

        [] ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:refresh, token, ttl}, _from, state) do
    result =
      case :ets.lookup(state.table, token) do
        [{^token, session}] ->
          if DateTime.compare(DateTime.utc_now(), session.expires_at) == :lt do
            updated = %{session | expires_at: DateTime.add(DateTime.utc_now(), ttl, :second)}
            :ets.insert(state.table, {token, updated})
            {:ok, updated}
          else
            :ets.delete(state.table, token)
            {:error, :expired}
          end

        [] ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:revoke, token}, _from, state) do
    :ets.delete(state.table, token)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:revoke_all, address}, _from, state) do
    # Find and delete all sessions for this address
    ms = [{{:"$1", %{address: :"$2"}}, [{:==, :"$2", address}], [:"$1"]}]

    state.table
    |> :ets.select(ms)
    |> Enum.each(&:ets.delete(state.table, &1))

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:list_by_address, address}, _from, state) do
    now = DateTime.utc_now()

    sessions =
      state.table
      |> :ets.tab2list()
      |> Enum.filter(fn {_token, session} ->
        session.address == address && DateTime.compare(now, session.expires_at) == :lt
      end)
      |> Enum.map(fn {_token, session} -> session end)

    {:reply, sessions, state}
  end

  @impl true
  def handle_call({:update_roles, token, roles}, _from, state) do
    result =
      case :ets.lookup(state.table, token) do
        [{^token, session}] ->
          if DateTime.compare(DateTime.utc_now(), session.expires_at) == :lt do
            updated = %{session | roles: roles}
            :ets.insert(state.table, {token, updated})
            {:ok, updated}
          else
            :ets.delete(state.table, token)
            {:error, :expired}
          end

        [] ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired(state.table)
    Process.send_after(self(), :cleanup, state.cleanup_interval)
    {:noreply, state}
  end

  # Private helpers

  defp generate_token do
    @token_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp validate_required(attrs, keys) do
    missing = Enum.filter(keys, fn k -> !Map.has_key?(attrs, k) || is_nil(Map.get(attrs, k)) end)

    case missing do
      [] -> :ok
      keys -> {:error, "missing required fields: #{Enum.join(Enum.map(keys, &Atom.to_string/1), ", ")}"}
    end
  end

  defp cleanup_expired(table) do
    now = DateTime.utc_now()

    table
    |> :ets.tab2list()
    |> Enum.each(fn {token, session} ->
      if DateTime.compare(now, session.expires_at) != :lt do
        :ets.delete(table, token)
      end
    end)
  end
end
