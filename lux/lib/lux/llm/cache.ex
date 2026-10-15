defmodule Lux.LLM.Cache do
  @moduledoc """
  Response cache for LLM requests with TTL expiration and max-capacity eviction.

  Generates deterministic SHA-256 cache keys from the provider, model, prompt,
  tools, and generation parameters so identical requests can be served without
  redundant API calls or token expenditure.
  """

  @table :lux_llm_response_cache
  @default_ttl_ms 300_000
  @default_max_entries 1_000

  @doc """
  Ensures the ETS cache table is initialized.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
          :ok
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  @doc """
  Clears all cached LLM responses.
  """
  @spec clear!() :: :ok
  def clear! do
    ensure_started()
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc """
  Builds a deterministic cache key from the prompt, tools, and request configuration.
  """
  @spec build_key(term(), list(), map()) :: String.t()
  def build_key(prompt, tools, config) when is_map(config) do
    tool_signatures =
      Enum.map(tools || [], fn
        %{name: name} -> name
        %{module_name: name} -> name
        mod when is_atom(mod) -> Atom.to_string(mod)
        other -> inspect(other)
      end)

    relevant_config = %{
      provider: Map.get(config, :provider),
      model: Map.get(config, :model),
      temperature: Map.get(config, :temperature),
      system: Map.get(config, :system),
      messages: Map.get(config, :messages, []),
      json_response: Map.get(config, :json_response),
      json_schema: Map.get(config, :json_schema)
    }

    payload = :erlang.term_to_binary({prompt, tool_signatures, relevant_config})

    :sha256
    |> :crypto.hash(payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Looks up a cached response by key, evicting the entry if its TTL has expired.
  """
  @spec get(String.t()) :: {:ok, term()} | :miss
  def get(key) when is_binary(key) do
    ensure_started()
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] when expires_at > now ->
        {:ok, value}

      [{^key, _value, _expired}] ->
        :ets.delete(@table, key)
        :miss

      [] ->
        :miss
    end
  end

  @doc """
  Stores a successful LLM response in the cache.

  ## Options
  - `:ttl_ms` (pos_integer, default `300_000`) - time-to-live in milliseconds
  - `:max_entries` (pos_integer, default `1_000`) - maximum cache entries before eviction
  """
  @spec put(String.t(), term(), keyword()) :: :ok
  def put(key, value, opts \\ []) when is_binary(key) do
    ensure_started()
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    max_entries = Keyword.get(opts, :max_entries, @default_max_entries)

    maybe_evict(max_entries)
    expires_at = System.monotonic_time(:millisecond) + ttl_ms
    :ets.insert(@table, {key, value, expires_at})
    :ok
  end

  @doc """
  Invalidates a specific cache key.
  """
  @spec invalidate(String.t()) :: :ok
  def invalidate(key) when is_binary(key) do
    ensure_started()
    :ets.delete(@table, key)
    :ok
  end

  @doc """
  Returns the current number of active entries in the cache.
  """
  @spec size() :: non_neg_integer()
  def size do
    ensure_started()
    now = System.monotonic_time(:millisecond)

    @table
    |> :ets.tab2list()
    |> Enum.count(fn {_k, _v, expires_at} -> expires_at > now end)
  end

  defp maybe_evict(max_entries) do
    current_size = :ets.info(@table, :size)

    if is_integer(current_size) and current_size >= max_entries do
      now = System.monotonic_time(:millisecond)
      entries = :ets.tab2list(@table)

      expired = Enum.filter(entries, fn {_k, _v, exp} -> exp <= now end)

      if expired == [] do
        {oldest_key, _v, _exp} = Enum.min_by(entries, fn {_k, _v, exp} -> exp end)
        :ets.delete(@table, oldest_key)
      else
        Enum.each(expired, fn {k, _v, _exp} -> :ets.delete(@table, k) end)
      end
    end
  end
end
