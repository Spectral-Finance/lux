defmodule Lux.Integrations.Web3.MultiChain.AggregatorTest do
  use ExUnit.Case, async: false

  alias Lux.Integrations.Web3.MultiChain.Aggregator
  alias Lux.Integrations.Web3.MultiChain.Storage

  setup do
    # Ensure Aggregator is running
    case Aggregator.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    Storage.clear()
    :ok
  end

  test "storage can insert and retrieve events" do
    Storage.insert_event("1", %{"transactionHash" => "0x123", "logIndex" => 0, "data" => "A"})
    Storage.insert_event("56", %{"transactionHash" => "0xabc", "logIndex" => 1, "data" => "B"})

    events = Storage.get_events()
    assert length(events) == 2

    bsc_events = Storage.get_events("56")
    assert length(bsc_events) == 1
    assert List.first(bsc_events).chain_id == "56"
  end

  test "storage retrieves latest blocks per chain" do
    Storage.insert_block("1", %{"number" => "0x1", "timestamp" => 100})
    Storage.insert_block("1", %{"number" => "0x2", "timestamp" => 200})
    Storage.insert_block("56", %{"number" => "0x5", "timestamp" => 150})

    blocks = Storage.get_latest_blocks()
    assert blocks["1"]["number"] == "0x2"
    assert blocks["56"]["number"] == "0x5"
  end
end
