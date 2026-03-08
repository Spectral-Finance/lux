defmodule Lux.Integrations.Web3.Events.EventDecoderTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Events.EventDecoder

  test "decodes ERC-20 Transfer event" do
    log = %{
      "topics" => [
        "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        "0x000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045",
        "0x000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f2bd73"
      ],
      "data" => "0x00000000000000000000000000000000000000000000000000000000000003e8",
      "address" => "0xdac17f958d2ee523a2206206994597c13d831ec7",
      "blockNumber" => "0xF4240",
      "transactionHash" => "0xtxhash",
      "logIndex" => "0x0"
    }

    event = EventDecoder.decode(log)
    assert event.type == :transfer
    assert event.from =~ ~r/d8da6bf/i
    assert event.to =~ ~r/742d35cc/i
    assert event.value == 1000
    assert event.address == "0xdac17f958d2ee523a2206206994597c13d831ec7"
  end

  test "decodes Approval event" do
    log = %{
      "topics" => [
        "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
        "0x000000000000000000000000aaaa",
        "0x000000000000000000000000bbbb"
      ],
      "data" => "0x00000000000000000000000000000000000000000000000000000000ffffffff",
      "address" => "0xtoken"
    }

    event = EventDecoder.decode(log)
    assert event.type == :approval
    assert event.owner =~ ~r/aaaa/
    assert event.spender =~ ~r/bbbb/
    assert event.value > 0
  end

  test "decodes unknown event" do
    log = %{
      "topics" => ["0xdeadbeef"],
      "data" => "0x1234",
      "address" => "0xcontract"
    }

    event = EventDecoder.decode(log)
    assert event.type == :unknown
    assert event.raw_data == "0x1234"
  end

  test "known_events returns map" do
    events = EventDecoder.known_events()
    assert map_size(events) >= 6
  end

  test "handles nil/empty data" do
    log = %{"topics" => [], "data" => "0x", "address" => "0x"}
    event = EventDecoder.decode(log)
    assert event.type == :unknown
  end
end
