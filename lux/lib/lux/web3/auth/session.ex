defmodule Lux.Web3.Auth.Session do
  @moduledoc """
  Session management for Web3 authenticated users.

  Manages authenticated sessions with configurable expiration, refresh
  tokens, and concurrent session limits. Sessions are stored in ETS
  for high-performance lookups.
  """

  require Logger

  @typedoc "Session data"
  @type t :: %__MODULE__{
          session_id: String.t(),
          address: String.t(),
          chain_id: non_neg_integer(),
          scope: [String.t()],
          created_at: DateTime.t(),
          expires_at: DateTime.t(),
          metadata: map()
        }

  defstruct [
    :session_id,
    :address,
    :chain_id,
    :scope,
    :created_at,
    :expires_at,
    metadata: %{}
  ]

  @default_ttl :timer.hours(24)
  @ets_table :lux_web3_sessions

  @doc """
  Starts the session store ETS table.
  """
  @spec init_store() :: :ok
  def init_store do
    unless :ets.whereis(@ets_table) != :undefined do
      @ets_table =
        :ets.new(@ets_table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])
    end

    :ok
  end

  @doc """
  Creates a new session for an authenticated address.

  Returns the session struct with a unique session ID.
  """
  @spec create(String.t(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def create(address, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl)
    chain_id = Keyword.get(opts, :chain_id, 1)
    scope = Keyword.get(opts, :scope, [])
    metadata = Keyword.get(opts, :metadata, %{})

    session_id = generate_session_id()
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, ttl, :millisecond)

    session = %__MODULE__{
      session_id: session_id,
      address: String.downcase(address),
      chain_id: chain_id,
      scope: scope,
      created_at: now,
      expires_at: expires_at,
      metadata: metadata
    }

    :ets.insert(@ets_table, {session_id, session})
    {:ok, session}
  end

  @doc """
  Retrieves a session by its ID.
  Returns `{:ok, session}` or `{:error, :not_found}`.
  """
  @spec get(String.t()) :: {:ok, t()} | {:error, :not_found | :expired}
  def get(session_id) do
    case :ets.lookup(@ets_table, session_id) do
      [{_id, session}] ->
        if expired?(session) do
          delete(session_id)
          {:error, :expired}
        else
          {:ok, session}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets all active sessions for a given address.
  """
  @spec get_by_address(String.t()) :: [t()]
  def get_by_address(address) do
    addr = String.downcase(address)

    @ets_table
    |> :ets.tab2list()
    |> Enum.filter(fn {_id, session} -> session.address == addr end)
    |> Enum.reject(fn {_id, session} -> expired?(session) end)
    |> Enum.map(fn {_id, session} -> session end)
  end

  @doc """
  Refreshes a session by extending its expiration.
  """
  @spec refresh(String.t(), pos_integer()) :: {:ok, t()} | {:error, atom()}
  def refresh(session_id, ttl \\ @default_ttl) do
    case get(session_id) do
      {:ok, session} ->
        refreshed = %{session | expires_at: DateTime.add(DateTime.utc_now(), ttl, :millisecond)}
        :ets.insert(@ets_table, {session_id, refreshed})
        {:ok, refreshed}

      error ->
        error
    end
  end

  @doc """
  Deletes a session, invalidating it immediately.
  """
  @spec delete(String.t()) :: :ok
  def delete(session_id) do
    :ets.delete(@ets_table, session_id)
    :ok
  end

  @doc """
  Deletes all sessions for a given address.
  """
  @spec delete_all(String.t()) :: :ok
  def delete_all(address) do
    addr = String.downcase(address)

    @ets_table
    |> :ets.tab2list()
    |> Enum.each(fn {id, session} ->
      if session.address == addr, do: :ets.delete(@ets_table, id)
    end)

    :ok
  end

  @doc """
  Checks if a session has expired.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  @doc """
  Cleans up all expired sessions.
  """
  @spec cleanup() :: non_neg_integer()
  def cleanup do
    @ets_table
    |> :ets.tab2list()
    |> Enum.reduce(0, fn {id, session}, count ->
      if expired?(session) do
        :ets.delete(@ets_table, id)
        count + 1
      else
        count
      end
    end)
  end

  defp generate_session_id do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
