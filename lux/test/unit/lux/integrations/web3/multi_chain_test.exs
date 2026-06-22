defmodule Lux.Integrations.Web3.MultiChain.IntegrationTest do
  use ExUnit.Case, async: false

  alias Lux.Integrations.Web3.MultiChain.Aggregator
  alias Lux.Integrations.Web3.MultiChain.Storage

  setup do
    Storage.clear()
    :ok
  end

  test "can add a chain and collect data (simulated)" do
    # Simulating data directly into storage to test aggregation
    # Real testing would require spinning up a fake RPC server with Bandit or Bypass
    
    Storage.insert_block(1, %{"number" => "0x1", "timestamp" => 100})
    Storage.insert_block(137, %{"number" => "0x2", "timestamp" => 105})
    
    Storage.insert_transaction(1, %{"hash" => "0xabc"})
    Storage.insert_event(137, %{"transactionHash" => "0xdef", "logIndex" => "0x0"})
    
    blocks = Aggregator.query_latest_blocks()
    assert Map.has_key?(blocks, 1)
    assert Map.has_key?(blocks, 137)
    
    events = Storage.get_events(137)
    assert length(events) == 1
    assert hd(events).transaction == "0xdef"
    
    txs = Storage.get_transactions(1)
    assert length(txs) == 1
    assert hd(txs).hash == "0xabc"
  end
end
