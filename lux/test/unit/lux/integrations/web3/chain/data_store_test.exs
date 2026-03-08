defmodule Lux.Integrations.Web3.Chain.DataStoreTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Chain.DataStore

  setup do
    {:ok, pid} = DataStore.start_link(name: nil, max_blocks: 50, max_txs: 100)
    %{pid: pid}
  end

  test "store and retrieve block", %{pid: pid} do
    block = %{number: 100, hash: "0xblock100", gas_used: 21000}
    :ok = DataStore.store_block(pid, block)
    assert {:ok, ^block} = DataStore.get_block(pid, 100)
  end

  test "store and retrieve transaction", %{pid: pid} do
    tx = %{hash: "0xtx1", from: "0xa", to: "0xb", value: 1000}
    :ok = DataStore.store_transaction(pid, tx)
    assert {:ok, ^tx} = DataStore.get_transaction(pid, "0xtx1")
  end

  test "get_block returns error for missing", %{pid: pid} do
    assert {:error, :not_found} = DataStore.get_block(pid, 999)
  end

  test "query_blocks with range", %{pid: pid} do
    for i <- 1..20 do
      DataStore.store_block(pid, %{number: i, hash: "0x#{i}"})
    end

    {:ok, blocks} = DataStore.query_blocks(pid, %{from_block: 5, to_block: 10})
    assert length(blocks) == 6
    assert Enum.all?(blocks, &(&1.number >= 5 and &1.number <= 10))
  end

  test "stats returns counts", %{pid: pid} do
    for i <- 1..5, do: DataStore.store_block(pid, %{number: i, hash: "0x#{i}"})
    for i <- 1..3, do: DataStore.store_transaction(pid, %{hash: "0xtx#{i}"})

    stats = DataStore.stats(pid)
    assert stats.blocks_stored == 5
    assert stats.txs_stored == 3
  end

  test "evicts oldest blocks when max exceeded", %{pid: pid} do
    for i <- 1..60 do
      DataStore.store_block(pid, %{number: i, hash: "0x#{i}"})
    end
    stats = DataStore.stats(pid)
    assert stats.blocks_stored <= 55  # max 50 + trigger at 51, evict 5
  end

  test "disk persistence round-trip" do
    # Start with persist_dir
    dir = Path.join(System.tmp_dir!(), "lux_datastore_test_#{:rand.uniform(100000)}")
    name1 = :"ds_persist_#{:rand.uniform(100000)}"
    {:ok, pid} = DataStore.start_link(name: name1, persist_dir: dir)

    DataStore.store_block(pid, %{number: 42, hash: "0x42"})
    DataStore.store_transaction(pid, %{hash: "0xtx42", value: 100})
    DataStore.persist(pid)

    # Verify files exist
    assert File.exists?(Path.join(dir, "blocks.etf"))
    assert File.exists?(Path.join(dir, "txs.etf"))

    # Start new store from same dir
    name2 = :"ds_persist2_#{:rand.uniform(100000)}"
    {:ok, pid2} = DataStore.start_link(name: name2, persist_dir: dir)
    assert {:ok, %{number: 42}} = DataStore.get_block(pid2, 42)
    assert {:ok, %{hash: "0xtx42"}} = DataStore.get_transaction(pid2, "0xtx42")

    # Cleanup
    File.rm_rf!(dir)
  end
end
