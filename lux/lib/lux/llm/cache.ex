defmodule Lux.LLM.Cache do
  @moduledoc """
  Content-addressable cache for LLM responses.

  Generates deterministic SHA-256 keys from prompts, parameters, and tools
  to eliminate redundant LLM calls and reduce API costs.
  """

  @default_ttl_seconds 3600

  @doc """
  Generates a deterministic hash key for a request.
  """
  @spec generate_key(String.t(), String.t(), term(), list()) :: String.t()
  def generate_key(prompt, model, params \\ %{}, tools \\ []) do
    payload = :erlang.term_to_binary({prompt, model, params, tools})
    :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
  end

  @doc """
  Retrieves a cached LLM response by key.
  """
  @spec get(String.t()) :: {:ok, Lux.LLM.Response.t()} | :miss
  def get(cache_key) do
    cache_store = Process.get(:lux_llm_cache_store, %{})

    case Map.get(cache_store, cache_key) do
      nil ->
        record_metric(:misses)
        :miss

      %{response: resp, expires_at: expires_at} ->
        now = System.system_time(:second)

        if now < expires_at do
          record_metric(:hits)
          {:ok, resp}
        else
          # Expired
          delete(cache_key)
          record_metric(:misses)
          :miss
        end
    end
  end

  @doc """
  Stores an LLM response in the cache.
  """
  @spec put(String.t(), Lux.LLM.Response.t(), integer()) :: :ok
  def put(cache_key, response, ttl_seconds \\ @default_ttl_seconds) do
    expires_at = System.system_time(:second) + ttl_seconds
    cache_store = Process.get(:lux_llm_cache_store, %{})
    updated = Map.put(cache_store, cache_key, %{response: response, expires_at: expires_at})
    Process.put(:lux_llm_cache_store, updated)
    :ok
  end

  @doc """
  Deletes a specific key.
  """
  @spec delete(String.t()) :: :ok
  def delete(cache_key) do
    cache_store = Process.get(:lux_llm_cache_store, %{})
    Process.put(:lux_llm_cache_store, Map.delete(cache_store, cache_key))
    :ok
  end

  @doc """
  Clears the entire cache.
  """
  @spec clear!() :: :ok
  def clear! do
    Process.put(:lux_llm_cache_store, %{})
    Process.put(:lux_llm_cache_stats, %{hits: 0, misses: 0})
    :ok
  end

  @doc """
  Returns cache statistics (hits, misses, item count).
  """
  @spec stats() :: map()
  def stats do
    stats = Process.get(:lux_llm_cache_stats, %{hits: 0, misses: 0})
    store = Process.get(:lux_llm_cache_store, %{})

    Map.merge(stats, %{cached_items: map_size(store)})
  end

  defp record_metric(field) do
    stats = Process.get(:lux_llm_cache_stats, %{hits: 0, misses: 0})
    current_val = Map.get(stats, field, 0)
    Process.put(:lux_llm_cache_stats, Map.put(stats, field, current_val + 1))
  end
end
