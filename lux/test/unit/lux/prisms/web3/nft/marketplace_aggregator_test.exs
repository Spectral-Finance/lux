defmodule Lux.Prisms.Web3.NFT.MarketplaceAggregatorTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.NFT.MarketplaceAggregator

  setup do
    name = :"nft_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = MarketplaceAggregator.start_link(name: name)
    %{pid: pid}
  end

  test "track collection", %{pid: pid} do
    {:ok, c} = MarketplaceAggregator.track_collection(pid, %{address: "0xbc4ca", name: "BAYC", floor_price: 30.5})
    assert c.name == "BAYC"
    assert c.marketplace == :opensea
  end

  test "track missing address", %{pid: pid} do
    assert {:error, :missing_address} = MarketplaceAggregator.track_collection(pid, %{name: "Test"})
  end

  test "get collection", %{pid: pid} do
    {:ok, _} = MarketplaceAggregator.track_collection(pid, %{address: "0xabc", name: "Test"})
    {:ok, c} = MarketplaceAggregator.get_collection(pid, "0xabc")
    assert c.name == "Test"
  end

  test "get not found", %{pid: pid} do
    assert {:error, :not_found} = MarketplaceAggregator.get_collection(pid, "nope")
  end

  test "untrack", %{pid: pid} do
    {:ok, _} = MarketplaceAggregator.track_collection(pid, %{address: "0x1"})
    :ok = MarketplaceAggregator.untrack_collection(pid, "0x1")
    assert {:error, :not_found} = MarketplaceAggregator.get_collection(pid, "0x1")
  end

  test "list collections", %{pid: pid} do
    {:ok, _} = MarketplaceAggregator.track_collection(pid, %{address: "0x1"})
    {:ok, _} = MarketplaceAggregator.track_collection(pid, %{address: "0x2"})
    {:ok, list} = MarketplaceAggregator.list_collections(pid)
    assert length(list) == 2
  end

  test "record sale", %{pid: pid} do
    {:ok, sale} = MarketplaceAggregator.record_sale(pid, %{collection: "0xabc", token_id: 1, price: 5.0})
    assert sale.collection == "0xabc"
    assert is_binary(sale.id)
  end

  test "record sale missing collection", %{pid: pid} do
    assert {:error, :missing_collection} = MarketplaceAggregator.record_sale(pid, %{price: 5.0})
  end

  test "record sale negative price", %{pid: pid} do
    assert {:error, :invalid_price} = MarketplaceAggregator.record_sale(pid, %{collection: "0x1", price: -1})
  end

  test "get sales", %{pid: pid} do
    {:ok, _} = MarketplaceAggregator.record_sale(pid, %{collection: "0xabc", price: 5.0})
    {:ok, _} = MarketplaceAggregator.record_sale(pid, %{collection: "0xabc", price: 6.0})
    {:ok, sales} = MarketplaceAggregator.get_sales(pid, "0xabc")
    assert length(sales) == 2
  end

  test "get sales empty", %{pid: pid} do
    {:ok, sales} = MarketplaceAggregator.get_sales(pid, "nonexistent")
    assert sales == []
  end

  test "watchlist add", %{pid: pid} do
    {:ok, entry} = MarketplaceAggregator.add_watchlist(pid, %{collection: "BAYC", floor_alert: 25.0})
    assert entry.collection == "BAYC"
  end

  test "watchlist missing collection", %{pid: pid} do
    assert {:error, :missing_collection} = MarketplaceAggregator.add_watchlist(pid, %{floor_alert: 10})
  end

  test "watchlist list", %{pid: pid} do
    {:ok, _} = MarketplaceAggregator.add_watchlist(pid, %{collection: "A"})
    {:ok, _} = MarketplaceAggregator.add_watchlist(pid, %{collection: "B"})
    {:ok, wl} = MarketplaceAggregator.get_watchlist(pid)
    assert length(wl) == 2
  end

  test "analyze rarity" do
    {:ok, r} = MarketplaceAggregator.analyze_rarity(["blue", "red", "blue", "green", "blue", "red"])
    assert r.total_score > 0
    assert r.rarity_rank in [:common, :uncommon, :rare, :legendary]
    assert map_size(r.traits) == 3
  end

  test "analyze rarity empty" do
    assert {:error, :empty_traits} = MarketplaceAggregator.analyze_rarity([])
  end

  test "compare collections" do
    collections = [%{name: "A", floor_price: 10}, %{name: "B", floor_price: 30}, %{name: "C", floor_price: 5}]
    {:ok, r} = MarketplaceAggregator.compare_collections(collections)
    assert hd(r.ranked).floor_price == 30
    assert r.avg_floor == 15.0
    assert r.count == 3
  end

  test "compare empty" do
    assert {:error, :empty_list} = MarketplaceAggregator.compare_collections([])
  end
end
