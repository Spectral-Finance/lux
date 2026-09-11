defmodule Lux.LLM.CacheTest do
  use UnitAPICase, async: false

  alias Lux.LLM.Cache
  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.ResponseSignal
  alias Lux.LLM.Router
  alias Lux.Signal

  defmodule MockProvider do
    @behaviour Lux.LLM.Provider

    @impl true
    def id, do: :cache_mock_provider

    @impl true
    def models do
      [
        %ModelConfig{
          id: "cache-model",
          name: "Cache Model",
          provider_id: :cache_mock_provider,
          cost_per_1k_prompt_tokens: 0.001,
          cost_per_1k_completion_tokens: 0.002,
          capabilities: [:tools]
        }
      ]
    end

    @impl true
    def call(prompt, _tools, _opts) do
      payload = %{
        content: %{"answer" => "response to #{prompt}"},
        model: "cache-model",
        finish_reason: "stop",
        tool_calls: nil,
        tool_calls_results: nil
      }

      {:ok, Signal.new(%{schema_id: ResponseSignal, payload: payload, metadata: %{call_count: 1}})}
    end
  end

  defp make_test_signal(content) do
    payload = %{
      content: %{"text" => content},
      model: "test-model",
      finish_reason: "stop",
      tool_calls: nil,
      tool_calls_results: nil
    }

    Signal.new(%{schema_id: ResponseSignal, payload: payload, metadata: %{source: :fresh}})
  end

  setup do
    table_name = :"test_cache_#{System.unique_integer([:positive])}"
    server_name = :"test_cache_server_#{System.unique_integer([:positive])}"

    {:ok, pid} = Cache.start_link(name: server_name, table: table_name)

    %{table: table_name, server: server_name, pid: pid}
  end

  describe "key/3 generation" do
    test "generates deterministic SHA-256 keys" do
      k1 = Cache.key("hello", [], model: "gpt-4o", temperature: 0.7)
      k2 = Cache.key("hello", [], model: "gpt-4o", temperature: 0.7)
      assert k1 == k2
      assert is_binary(k1)
      assert byte_size(k1) == 64
    end

    test "differentiates keys when prompt or options differ" do
      k1 = Cache.key("hello", [], model: "gpt-4o")
      k2 = Cache.key("world", [], model: "gpt-4o")
      k3 = Cache.key("hello", [], model: "claude-3")

      assert k1 != k2
      assert k1 != k3
      assert k2 != k3
    end

    test "ignores non-caching control options like :cache or :ttl" do
      k1 = Cache.key("hello", [], model: "gpt-4o", cache: true, ttl: 500)
      k2 = Cache.key("hello", [], model: "gpt-4o", cache: false, ttl: 9999)
      assert k1 == k2
    end
  end

  describe "get/2 and put/3 operations" do
    test "returns :miss on cache miss and records miss stat", %{table: tbl, server: srv} do
      opts = [table: tbl, name: srv]
      assert :miss == Cache.get("non-existent-key", opts)

      stats = Cache.stats(opts)
      assert stats.misses >= 1
      assert stats.hits == 0
    end

    test "stores and retrieves cached signal marking metadata.cached: true", %{table: tbl, server: srv} do
      opts = [table: tbl, name: srv]
      signal = make_test_signal("cached response")
      key = "my-key-1"

      assert :ok == Cache.put(key, signal, opts)
      assert {:ok, cached} = Cache.get(key, opts)

      assert cached.payload.content["text"] == "cached response"
      assert cached.metadata[:cached] == true

      stats = Cache.stats(opts)
      assert stats.hits >= 1
      assert stats.size == 1
    end

    test "deletes an entry", %{table: tbl, server: srv} do
      opts = [table: tbl, name: srv]
      signal = make_test_signal("test")
      key = "to-delete"

      Cache.put(key, signal, opts)
      assert {:ok, _} = Cache.get(key, opts)

      assert :ok == Cache.delete(key, opts)
      assert :miss == Cache.get(key, opts)
    end

    test "clears all entries", %{table: tbl, server: srv} do
      opts = [table: tbl, name: srv]
      Cache.put("k1", make_test_signal("1"), opts)
      Cache.put("k2", make_test_signal("2"), opts)

      stats_before = Cache.stats(opts)
      assert stats_before.size == 2

      assert :ok == Cache.clear(opts)

      stats_after = Cache.stats(opts)
      assert stats_after.size == 0
    end
  end

  describe "cached_call/4" do
    test "executes function once on miss and returns cached on second call", %{table: tbl, server: srv} do
      opts = [table: tbl, name: srv, model: "test-model"]
      counter = :counters.new(1, [:atomics])

      call_fun = fn _prompt, _tools ->
        :counters.add(counter, 1, 1)
        {:ok, make_test_signal("count-#{:counters.get(counter, 1)}")}
      end

      assert {:ok, s1} = Cache.cached_call(call_fun, "prompt1", [], opts)
      assert s1.payload.content["text"] == "count-1"
      assert s1.metadata[:cached] != true

      assert {:ok, s2} = Cache.cached_call(call_fun, "prompt1", [], opts)
      assert s2.payload.content["text"] == "count-1"
      assert s2.metadata[:cached] == true
      assert :counters.get(counter, 1) == 1
    end

    test "bypasses cache when cache: false is provided", %{table: tbl, server: srv} do
      opts = [table: tbl, name: srv, cache: false]
      counter = :counters.new(1, [:atomics])

      call_fun = fn _prompt, _tools ->
        :counters.add(counter, 1, 1)
        {:ok, make_test_signal("bypassed-#{:counters.get(counter, 1)}")}
      end

      assert {:ok, s1} = Cache.cached_call(call_fun, "prompt-bypass", [], opts)
      assert s1.payload.content["text"] == "bypassed-1"

      assert {:ok, s2} = Cache.cached_call(call_fun, "prompt-bypass", [], opts)
      assert s2.payload.content["text"] == "bypassed-2"
      assert :counters.get(counter, 1) == 2
    end

    test "does not cache error responses", %{table: tbl, server: srv} do
      opts = [table: tbl, name: srv]
      error_fun = fn _prompt, _tools -> {:error, :rate_limit} end

      assert {:error, :rate_limit} = Cache.cached_call(error_fun, "err-prompt", [], opts)
      key = Cache.key("err-prompt", [], opts)
      assert :miss == Cache.get(key, opts)
    end
  end

  describe "Router caching integration" do
    test "Router.call with cache: true caches responses" do
      reg_name = :"router_cache_reg_#{System.unique_integer([:positive])}"
      table_name = :"router_cache_tbl_#{System.unique_integer([:positive])}"
      server_name = :"router_cache_srv_#{System.unique_integer([:positive])}"

      {:ok, _} = ProviderRegistry.start_link(name: reg_name, providers: [MockProvider])
      {:ok, _} = Cache.start_link(name: server_name, table: table_name)

      opts = [
        registry_name: reg_name,
        table: table_name,
        name: server_name,
        cache: true,
        provider_id: :cache_mock_provider
      ]

      assert {:ok, signal1} = Router.call("cache query", [], opts)
      assert signal1.payload.content["answer"] == "response to cache query"

      assert {:ok, signal2} = Router.call("cache query", [], opts)
      assert signal2.payload.content["answer"] == "response to cache query"
      assert signal2.metadata[:cached] == true
    end
  end
end
