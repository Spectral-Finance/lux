defmodule Lux.MultiChain.CacheTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.MultiChain.Cache

  setup do
    Cache.init()
    Cache.clear_all()
    :ok
  end

  describe "init/0" do
    test "creates the ETS table" do
      Cache.init()
      assert :ets.whereis(:lux_multichain_cache) != :undefined
    end

    test "is idempotent" do
      Cache.init()
      Cache.init()
      assert :ets.whereis(:lux_multichain_cache) != :undefined
    end
  end

  describe "put/4 and get/2" do
    test "stores and retrieves a value" do
      Cache.put(:ethereum, "test_key", %{value: 42})
      assert {:ok, %{value: 42}} = Cache.get(:ethereum, "test_key")
    end

    test "stores values for different chains independently" do
      Cache.put(:ethereum, "block", %{number: 100})
      Cache.put(:polygon, "block", %{number: 200})

      assert {:ok, %{number: 100}} = Cache.get(:ethereum, "block")
      assert {:ok, %{number: 200}} = Cache.get(:polygon, "block")
    end

    test "returns :miss for non-existent keys" do
      assert :miss = Cache.get(:ethereum, "nonexistent")
    end

    test "respects TTL expiration" do
      Cache.put(:ethereum, "short_lived", "data", ttl: 1)
      Process.sleep(10)
      assert :miss = Cache.get(:ethereum, "short_lived")
    end

    test "keeps non-expired entries" do
      Cache.put(:ethereum, "long_lived", "data", ttl: 60_000)
      assert {:ok, "data"} = Cache.get(:ethereum, "long_lived")
    end

    test "overwrites existing values" do
      Cache.put(:ethereum, "key", "old_value")
      Cache.put(:ethereum, "key", "new_value")
      assert {:ok, "new_value"} = Cache.get(:ethereum, "key")
    end
  end

  describe "delete/2" do
    test "removes a specific entry" do
      Cache.put(:ethereum, "key", "value")
      Cache.delete(:ethereum, "key")
      assert :miss = Cache.get(:ethereum, "key")
    end

    test "does not affect other entries" do
      Cache.put(:ethereum, "key1", "value1")
      Cache.put(:ethereum, "key2", "value2")
      Cache.delete(:ethereum, "key1")
      assert :miss = Cache.get(:ethereum, "key1")
      assert {:ok, "value2"} = Cache.get(:ethereum, "key2")
    end
  end

  describe "clear_chain/1" do
    test "clears all entries for a specific chain" do
      Cache.put(:ethereum, "key1", "val1")
      Cache.put(:ethereum, "key2", "val2")
      Cache.put(:polygon, "key1", "val1")

      Cache.clear_chain(:ethereum)

      assert :miss = Cache.get(:ethereum, "key1")
      assert :miss = Cache.get(:ethereum, "key2")
      assert {:ok, "val1"} = Cache.get(:polygon, "key1")
    end
  end

  describe "clear_all/0" do
    test "removes all entries" do
      Cache.put(:ethereum, "key", "val")
      Cache.put(:polygon, "key", "val")

      Cache.clear_all()

      assert :miss = Cache.get(:ethereum, "key")
      assert :miss = Cache.get(:polygon, "key")
    end
  end

  describe "size/0" do
    test "returns the number of cached entries" do
      assert Cache.size() == 0

      Cache.put(:ethereum, "key1", "val1")
      assert Cache.size() == 1

      Cache.put(:polygon, "key2", "val2")
      assert Cache.size() == 2
    end
  end

  describe "cleanup_expired/0" do
    test "removes expired entries and returns count" do
      Cache.put(:ethereum, "expired1", "val", ttl: 1)
      Cache.put(:ethereum, "expired2", "val", ttl: 1)
      Cache.put(:ethereum, "valid", "val", ttl: 60_000)

      Process.sleep(10)

      removed = Cache.cleanup_expired()
      assert removed == 2
      assert :miss = Cache.get(:ethereum, "expired1")
      assert {:ok, "val"} = Cache.get(:ethereum, "valid")
    end
  end

  describe "fetch_or_store/4" do
    test "returns cached value when present" do
      Cache.put(:ethereum, "key", "cached_value")

      result = Cache.fetch_or_store(:ethereum, "key", [], fn ->
        {:ok, "fresh_value"}
      end)

      assert {:ok, "cached_value"} = result
    end

    test "calls function and caches result on miss" do
      result = Cache.fetch_or_store(:ethereum, "new_key", [], fn ->
        {:ok, "computed_value"}
      end)

      assert {:ok, "computed_value"} = result
      assert {:ok, "computed_value"} = Cache.get(:ethereum, "new_key")
    end

    test "does not cache error results" do
      result = Cache.fetch_or_store(:ethereum, "err_key", [], fn ->
        {:error, "something went wrong"}
      end)

      assert {:error, "something went wrong"} = result
      assert :miss = Cache.get(:ethereum, "err_key")
    end

    test "respects custom TTL" do
      Cache.fetch_or_store(:ethereum, "ttl_key", [ttl: 1], fn ->
        {:ok, "short_lived"}
      end)

      Process.sleep(10)
      assert :miss = Cache.get(:ethereum, "ttl_key")
    end
  end
end
