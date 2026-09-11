defmodule Lux.LLM.Cache do
  @moduledoc """
  In-memory ETS-backed cache for LLM provider responses.

  Provides deterministic request hashing, TTL-based expiration, cache statistics
  (hits, misses, entries), and automatic eviction of expired entries.
  Implements the caching and optimization features specified in Issue #99.
  """

  use GenServer

  alias Lux.Signal

  @default_table :lux_llm_cache
  @default_ttl_seconds 3600
  @cleanup_interval_ms 60_000

  @type prompt :: Lux.LLM.Provider.prompt()
  @type tools :: Lux.LLM.Provider.tools()
  @type opts :: map() | keyword()
  @type cache_key :: binary()

  # --- Client API ---

  @doc """
  Starts the LLM Cache GenServer and initializes the backing ETS table.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Generates a deterministic SHA-256 cache key from prompt, tools, and options.
  """
  @spec key(prompt(), tools(), opts()) :: cache_key()
  def key(prompt, tools \\ [], opts \\ []) do
    opts_map = to_map(opts)

    relevant_opts =
      Map.take(opts_map, [
        :model,
        :temperature,
        :system,
        :max_tokens,
        :provider_id,
        :top_p,
        :json_response
      ])

    normalized_prompt = normalize_prompt(prompt)
    normalized_tools = normalize_tools(tools)

    data = :erlang.term_to_binary({normalized_prompt, normalized_tools, relevant_opts})
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  @doc """
  Fetches a cached response signal by key. Returns `{:ok, signal}` or `:miss`.
  """
  @spec get(cache_key(), opts()) :: {:ok, Signal.t()} | :miss
  def get(cache_key, opts \\ []) do
    table = get_table(opts)
    now = System.system_time(:second)

    case safe_ets_lookup(table, cache_key) do
      [{^cache_key, %Signal{} = signal, expires_at}] when expires_at > now ->
        record_stat(opts, :hit)
        metadata = Map.put(signal.metadata || %{}, :cached, true)
        {:ok, %{signal | metadata: metadata}}

      [{^cache_key, _signal, _expired}] ->
        safe_ets_delete(table, cache_key)
        record_stat(opts, :miss)
        :miss

      _ ->
        record_stat(opts, :miss)
        :miss
    end
  end

  @doc """
  Stores a response signal in the cache with a specified TTL (in seconds).
  """
  @spec put(cache_key(), Signal.t(), opts()) :: :ok
  def put(cache_key, %Signal{} = signal, opts \\ []) do
    table = get_table(opts)
    ttl = Keyword.get(opts, :ttl, @default_ttl_seconds)
    expires_at = System.system_time(:second) + max(1, ttl)

    safe_ets_insert(table, {cache_key, signal, expires_at})
    :ok
  end

  @doc """
  Deletes an entry from the cache by key.
  """
  @spec delete(cache_key(), opts()) :: :ok
  def delete(cache_key, opts \\ []) do
    table = get_table(opts)
    safe_ets_delete(table, cache_key)
    :ok
  end

  @doc """
  Clears all entries from the cache table.
  """
  @spec clear(opts()) :: :ok
  def clear(opts \\ []) do
    table = get_table(opts)
    safe_ets_delete_all(table)
    :ok
  end

  @doc """
  Executes a call through the cache. Returns cached response if present;
  otherwise invokes `fun_or_spec`, caches the result, and returns it.
  """
  @spec cached_call(term(), prompt(), tools(), opts()) :: {:ok, Signal.t()} | {:error, term()}
  def cached_call(fun_or_spec, prompt, tools \\ [], opts \\ []) do
    opts_map = to_map(opts)

    if Map.get(opts_map, :cache, true) == false do
      invoke_target(fun_or_spec, prompt, tools, opts_map)
    else
      cache_opts = Keyword.new(opts_map)
      cache_key = key(prompt, tools, opts_map)
      fetch_or_invoke(cache_key, cache_opts, fun_or_spec, prompt, tools, opts_map)
    end
  end

  defp fetch_or_invoke(cache_key, cache_opts, fun_or_spec, prompt, tools, opts_map) do
    case get(cache_key, cache_opts) do
      {:ok, %Signal{} = cached_signal} ->
        {:ok, cached_signal}

      :miss ->
        invoke_and_cache(cache_key, cache_opts, fun_or_spec, prompt, tools, opts_map)
    end
  end

  defp invoke_and_cache(cache_key, cache_opts, fun_or_spec, prompt, tools, opts_map) do
    case invoke_target(fun_or_spec, prompt, tools, opts_map) do
      {:ok, %Signal{} = fresh_signal} ->
        put(cache_key, fresh_signal, cache_opts)
        {:ok, fresh_signal}

      error ->
        error
    end
  end

  @doc """
  Returns cache statistics: hits, misses, and current entry count.
  """
  @spec stats(opts()) :: %{hits: integer(), misses: integer(), size: integer()}
  def stats(opts \\ []) do
    server = Keyword.get(opts, :name, __MODULE__)
    table = get_table(opts)

    server_stats =
      case GenServer.whereis(server) do
        nil -> %{hits: 0, misses: 0}
        _pid ->
          try do
            GenServer.call(server, :stats)
          catch
            :exit, _ -> %{hits: 0, misses: 0}
          end
      end

    size = safe_ets_info_size(table)
    Map.put(server_stats, :size, size)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    table = Keyword.get(opts, :table, @default_table)
    init_table(table)

    schedule_cleanup()

    {:ok, %{table: table, hits: 0, misses: 0}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, %{hits: state.hits, misses: state.misses}, state}
  end

  @impl true
  def handle_cast({:record, :hit}, state) do
    {:noreply, %{state | hits: state.hits + 1}}
  end

  def handle_cast({:record, :miss}, state) do
    {:noreply, %{state | misses: state.misses + 1}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired_entries(state.table)
    schedule_cleanup()
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # --- Internal Helpers ---

  defp init_table(table) do
    if :ets.info(table) == :undefined do
      :ets.new(table, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp cleanup_expired_entries(table) do
    now = System.system_time(:second)
    match_spec = [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}]

    try do
      :ets.select_delete(table, match_spec)
    catch
      :error, :badarg -> 0
    end
  end

  defp record_stat(opts, type) do
    server = Keyword.get(opts, :name, __MODULE__)

    case GenServer.whereis(server) do
      nil -> :ok
      _pid ->
        try do
          GenServer.cast(server, {:record, type})
        catch
          :exit, _ -> :ok
        end
    end
  end

  defp invoke_target(fun, prompt, tools, _opts) when is_function(fun, 2) do
    fun.(prompt, tools)
  end

  defp invoke_target(fun, prompt, tools, opts) when is_function(fun, 3) do
    fun.(prompt, tools, opts)
  end

  defp invoke_target(module, prompt, tools, opts) when is_atom(module) do
    if function_exported?(module, :call, 3) do
      module.call(prompt, tools, opts)
    else
      {:error, {:unknown_target, module}}
    end
  end

  defp invoke_target({module, spec_opts}, prompt, tools, opts) when is_atom(module) do
    merged = Map.merge(opts, to_map(spec_opts))
    invoke_target(module, prompt, tools, merged)
  end

  defp invoke_target(other, _prompt, _tools, _opts) do
    {:error, {:invalid_target, other}}
  end

  defp normalize_prompt(prompt) when is_binary(prompt), do: prompt
  defp normalize_prompt(messages) when is_list(messages), do: messages
  defp normalize_prompt(other), do: inspect(other)

  defp normalize_tools(tools) when is_list(tools) do
    Enum.map(tools, fn
      tool when is_atom(tool) -> tool
      %{name: name} -> name
      tool -> inspect(tool)
    end)
  end

  defp normalize_tools(_), do: []

  defp get_table(opts) do
    Keyword.get(opts, :table, @default_table)
  end

  defp safe_ets_lookup(table, key) do
    try do
      :ets.lookup(table, key)
    catch
      :error, :badarg -> []
    end
  end

  defp safe_ets_insert(table, tuple) do
    try do
      :ets.insert(table, tuple)
    catch
      :error, :badarg -> false
    end
  end

  defp safe_ets_delete(table, key) do
    try do
      :ets.delete(table, key)
    catch
      :error, :badarg -> false
    end
  end

  defp safe_ets_delete_all(table) do
    try do
      :ets.delete_all_objects(table)
    catch
      :error, :badarg -> false
    end
  end

  defp safe_ets_info_size(table) do
    try do
      :ets.info(table, :size) || 0
    catch
      :error, :badarg -> 0
    end
  end

  defp to_map(opts) when is_map(opts), do: opts
  defp to_map(opts) when is_list(opts), do: Enum.into(opts, %{})
  defp to_map(_), do: %{}
end
