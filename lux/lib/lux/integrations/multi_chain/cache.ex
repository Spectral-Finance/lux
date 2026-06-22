defmodule Lux.Integrations.MultiChain.Cache do
  @moduledoc """
  In-memory cache layer for multi-chain data.

  Provides TTL-based caching for chain adapter responses to reduce
  redundant RPC calls. Uses ETS for concurrent, lock-free reads.

  ## Configuration

      config :lux, Lux.Integrations.MultiChain.Cache,
        default_ttl: 30_000,
        chains: %{ethereum: 15_000, polygon: 10_000}

  ## Usage

      Cache.start_link()
      Cache.put({:balance, :ethereum, "0x..."}, %{balance: 1.5}, 15_000)
      Cache.get({:balance, :ethereum, "0x..."})
      Cache.invalidate({:balance, :ethereum, "0x..."})
      Cache.clear_chain(:ethereum)
      Cache.flush()
  """

  use GenServer

  @type cache_key :: {operation :: atom(), chain :: atom(), String.t()}
  @type cache_value :: term()
  @type ttl :: pos_integer() | :infinity

  @default_table :multi_chain_cache
  @default_ttl 30_000

  @doc """
  Starts the cache GenServer and creates the ETS table.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    table = :ets.new(@default_table, [:set, :named_table, :public, :read_concurrency: true])
    ttl = Application.get_env(:lux, __MODULE__, []) |> Keyword.get(:default_ttl, @default_ttl)
    {:ok, %{table: table, ttl: ttl}}
  end

  @doc """
  Puts a value into the cache with an optional TTL (milliseconds).
  """
  @spec put(cache_key(), cache_value(), ttl()) :: :ok
  def put(key, value, ttl_ms \\ @default_ttl), do: GenServer.call(__MODULE__, {:put, key, value, ttl_ms})

  @doc """
  Gets a value from the cache. Returns `{:ok, value}` or `:miss`.
  """
  @spec get(cache_key()) :: {:ok, cache_value()} | :miss
  def get(key), do: GenServer.call(__MODULE__, {:get, key})

  @doc """
  Invalidates a single cache entry.
  """
  @spec invalidate(cache_key()) :: :ok
  def invalidate(key), do: GenServer.cast(__MODULE__, {:invalidate, key})

  @doc """
  Clears all cache entries for a given chain.
  """
  @spec clear_chain(chain()) :: non_neg_integer()
  def clear_chain(chain), do: GenServer.call(__MODULE__, {:clear_chain, chain})

  @doc """
  Flushes the entire cache. Returns the number of entries removed.
  """
  @spec flush() :: non_neg_integer()
  def flush(), do: GenServer.call(__MODULE__, :flush)

  @doc """
  Returns the current cache size (number of entries).
  """
  @spec size() :: non_neg_integer()
  def size(), do: GenServer.call(__MODULE__, :size)

  @doc """
  Returns the configured default TTL in milliseconds.
  """
  @spec default_ttl() :: pos_integer()
  def default_ttl(), do: GenServer.call(__MODULE__, :ttl)

  @impl true
  def handle_call({:put, key, value, ttl_ms}, _from, state) do
    table = state.table
    cache_key = encode_key(key)
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(table, {cache_key, value, expires_at})
    {:reply, :ok, state}
  end

  def handle_call({:get, key}, _from, state) do
    table = state.table
    cache_key = encode_key(key)

    case :ets.lookup(table, cache_key) do
      [{^cache_key, value, expires_at}] when System.monotonic_time(:millisecond) < expires_at ->
        {:reply, {:ok, value}, state}

      [{^cache_key, _value, _expires_at}] ->
        :ets.delete(table, cache_key)
        {:reply, :miss, state}

      [] ->
        {:reply, :miss, state}
    end
  end

  def handle_call({:clear_chain, chain}, _from, state) do
    table = state.table
    count = purge_chain(table, chain)
    {:reply, count, state}
  end

  def handle_call(:flush, _from, state) do
    table = state.table
    count = :ets.info(table, :size)
    :ets.delete_all_objects(table)
    {:reply, count, state}
  end

  def handle_call(:size, _from, state) do
    {:reply, :ets.info(state.table, :size), state}
  end

  def handle_call(:ttl, _from, state) do
    {:reply, state.ttl, state}
  end

  @impl true
  def handle_cast({:invalidate, key}, state) do
    table = state.table
    :ets.delete(table, encode_key(key))
    {:noreply, state}
  end

  defp encode_key({op, chain, address}) do
    :erlang.phash2("#{op}:#{chain}:#{address}")
  end

  defp purge_chain(table, chain) do
    all_entries = :ets.tab2list(table)
    chain_str = chain_to_string(chain)
    to_delete = Enum.filter(all_entries, fn {key, _value, _expires} ->
      is_integer(key) and key_to_string(key) =~ chain_str
    end)

    for key <- to_delete, do: :ets.delete(table, key)
    length(to_delete)
  end

  defp chain_to_string(chain), do: Atom.to_string(chain)
  defp key_to_string(hash), do: Integer.to_string(hash)
end
