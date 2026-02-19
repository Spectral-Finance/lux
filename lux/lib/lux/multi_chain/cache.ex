defmodule Lux.MultiChain.Cache do
  @moduledoc """
  ETS-based caching layer for multi-chain data aggregation.

  Provides TTL-based caching with automatic expiration to reduce redundant
  RPC/API calls across chains. Each cache entry includes a timestamp for
  TTL enforcement and chain-specific namespacing.

  ## Features

  - Per-chain namespaced keys
  - Configurable TTL per entry type
  - Automatic stale entry cleanup
  - Thread-safe ETS operations

  ## Usage

      # Initialize the cache (called by supervisor)
      Lux.MultiChain.Cache.init()

      # Store a value with TTL
      Lux.MultiChain.Cache.put(:ethereum, "block:latest", block_data, ttl: 12_000)

      # Retrieve a cached value
      case Lux.MultiChain.Cache.get(:ethereum, "block:latest") do
        {:ok, data} -> data
        :miss -> fetch_fresh_data()
      end
  """

  @table :lux_multichain_cache
  @default_ttl_ms 30_000

  @type cache_key :: String.t()
  @type chain_id :: atom()

  @doc """
  Initializes the ETS table for caching. Idempotent.
  """
  @spec init() :: :ok
  def init do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
        :ok

      _ref ->
        :ok
    end
  end

  @doc """
  Retrieves a cached value for the given chain and key.

  Returns `{:ok, value}` if found and not expired, `:miss` otherwise.
  Expired entries are lazily cleaned up on access.

  ## Examples

      iex> Lux.MultiChain.Cache.get(:ethereum, "gas_price")
      {:ok, %{fast: 50, standard: 30}}

      iex> Lux.MultiChain.Cache.get(:polygon, "nonexistent")
      :miss
  """
  @spec get(chain_id(), cache_key()) :: {:ok, term()} | :miss
  def get(chain, key) do
    full_key = make_key(chain, key)

    case safe_lookup(full_key) do
      [{^full_key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:ok, value}
        else
          delete(chain, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  @doc """
  Stores a value in the cache with the given TTL.

  ## Options

  - `:ttl` - Time to live in milliseconds (default: #{@default_ttl_ms})

  ## Examples

      iex> Lux.MultiChain.Cache.put(:ethereum, "block:latest", %{number: 123}, ttl: 12_000)
      :ok
  """
  @spec put(chain_id(), cache_key(), term(), keyword()) :: :ok
  def put(chain, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, @default_ttl_ms)
    full_key = make_key(chain, key)
    expires_at = System.monotonic_time(:millisecond) + ttl
    safe_insert(full_key, value, expires_at)
    :ok
  end

  @doc """
  Deletes a specific cache entry.
  """
  @spec delete(chain_id(), cache_key()) :: :ok
  def delete(chain, key) do
    full_key = make_key(chain, key)
    safe_delete(full_key)
    :ok
  end

  @doc """
  Clears all cache entries for a specific chain.
  """
  @spec clear_chain(chain_id()) :: :ok
  def clear_chain(chain) do
    prefix = "#{chain}:"

    case :ets.whereis(@table) do
      :undefined ->
        :ok

      _ref ->
        :ets.foldl(
          fn {key, _val, _exp}, acc ->
            if is_binary(key) and String.starts_with?(key, prefix) do
              :ets.delete(@table, key)
            end

            acc
          end,
          :ok,
          @table
        )
    end
  end

  @doc """
  Clears all cache entries.
  """
  @spec clear_all() :: :ok
  def clear_all do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _ref -> :ets.delete_all_objects(@table)
    end

    :ok
  end

  @doc """
  Removes all expired entries from the cache.
  Returns the number of entries removed.
  """
  @spec cleanup_expired() :: non_neg_integer()
  def cleanup_expired do
    now = System.monotonic_time(:millisecond)

    case :ets.whereis(@table) do
      :undefined ->
        0

      _ref ->
        :ets.foldl(
          fn {key, _val, expires_at}, count ->
            if now >= expires_at do
              :ets.delete(@table, key)
              count + 1
            else
              count
            end
          end,
          0,
          @table
        )
    end
  end

  @doc """
  Returns the number of entries currently in the cache.
  """
  @spec size() :: non_neg_integer()
  def size do
    case :ets.whereis(@table) do
      :undefined -> 0
      _ref -> :ets.info(@table, :size)
    end
  end

  @doc """
  Fetches from cache or executes the given function to populate it.

  ## Examples

      Lux.MultiChain.Cache.fetch_or_store(:ethereum, "gas_price", [ttl: 15_000], fn ->
        {:ok, fetch_gas_price_from_api()}
      end)
  """
  @spec fetch_or_store(chain_id(), cache_key(), keyword(), (-> {:ok, term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def fetch_or_store(chain, key, opts \\ [], fun) do
    case get(chain, key) do
      {:ok, value} ->
        {:ok, value}

      :miss ->
        case fun.() do
          {:ok, value} ->
            put(chain, key, value, opts)
            {:ok, value}

          {:error, _} = error ->
            error
        end
    end
  end

  # Private helpers

  defp make_key(chain, key), do: "#{chain}:#{key}"

  defp safe_lookup(key) do
    case :ets.whereis(@table) do
      :undefined -> []
      _ref -> :ets.lookup(@table, key)
    end
  end

  defp safe_insert(key, value, expires_at) do
    case :ets.whereis(@table) do
      :undefined ->
        init()
        :ets.insert(@table, {key, value, expires_at})

      _ref ->
        :ets.insert(@table, {key, value, expires_at})
    end
  end

  defp safe_delete(key) do
    case :ets.whereis(@table) do
      :undefined -> true
      _ref -> :ets.delete(@table, key)
    end
  end
end
