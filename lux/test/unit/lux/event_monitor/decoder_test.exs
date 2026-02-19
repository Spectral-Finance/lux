defmodule Lux.EventMonitor.DecoderTest do
  use UnitCase, async: true

  alias Lux.EventMonitor.Decoder
  alias Lux.EventMonitor.EventLog

  @transfer_abi [
    %{
      "type" => "event",
      "name" => "Transfer",
      "inputs" => [
        %{"name" => "from", "type" => "address", "indexed" => true},
        %{"name" => "to", "type" => "address", "indexed" => true},
        %{"name" => "value", "type" => "uint256", "indexed" => false}
      ]
    }
  ]

  @approval_abi [
    %{
      "type" => "event",
      "name" => "Approval",
      "inputs" => [
        %{"name" => "owner", "type" => "address", "indexed" => true},
        %{"name" => "spender", "type" => "address", "indexed" => true},
        %{"name" => "value", "type" => "uint256", "indexed" => false}
      ]
    }
  ]

  @mixed_abi @transfer_abi ++ @approval_abi ++ [
    %{"type" => "function", "name" => "transfer", "inputs" => []}
  ]

  describe "new/1" do
    test "creates decoder from ABI with event entries" do
      decoder = Decoder.new(@transfer_abi)
      assert map_size(decoder.events_by_topic) == 1
    end

    test "handles ABI with multiple event types" do
      decoder = Decoder.new(@mixed_abi)
      assert map_size(decoder.events_by_topic) == 2
    end

    test "ignores non-event ABI entries" do
      abi = [%{"type" => "function", "name" => "transfer", "inputs" => []}]
      decoder = Decoder.new(abi)
      assert map_size(decoder.events_by_topic) == 0
    end

    test "handles empty ABI" do
      decoder = Decoder.new([])
      assert map_size(decoder.events_by_topic) == 0
    end

    test "handles non-list input" do
      decoder = Decoder.new("not a list")
      assert map_size(decoder.events_by_topic) == 0
    end
  end

  describe "event_topic/1" do
    test "computes correct keccak256 hash for Transfer event" do
      topic = Decoder.event_topic("Transfer(address,address,uint256)")
      assert topic == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    end

    test "computes correct keccak256 hash for Approval event" do
      topic = Decoder.event_topic("Approval(address,address,uint256)")
      assert topic == "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
    end
  end

  describe "decode_log/2" do
    test "decodes a Transfer event log" do
      decoder = Decoder.new(@transfer_abi)
      transfer_topic = Decoder.event_topic("Transfer(address,address,uint256)")

      from_addr = "0x000000000000000000000000ab5801a7d398351b8be11c439e05c5b3259aec9b"
      to_addr = "0x0000000000000000000000004838b106fce9647bdf1e7877bf73ce8b0bad5f97"

      event_log = %EventLog{
        address: "0xdead",
        topics: [transfer_topic, from_addr, to_addr],
        data: "0x00000000000000000000000000000000000000000000000000000000000f4240",
        block_number: 100,
        transaction_hash: "0xabc",
        log_index: 0,
        chain_id: 1
      }

      decoded = Decoder.decode_log(decoder, event_log)

      assert decoded.event_name == "Transfer"
      assert decoded.decoded_params["from"] == "0xab5801a7d398351b8be11c439e05c5b3259aec9b"
      assert decoded.decoded_params["to"] == "0x4838b106fce9647bdf1e7877bf73ce8b0bad5f97"
      assert decoded.decoded_params["value"] == 1_000_000
    end

    test "returns event unchanged when topic not recognized" do
      decoder = Decoder.new(@transfer_abi)

      event_log = %EventLog{
        address: "0xdead",
        topics: ["0x0000000000000000000000000000000000000000000000000000000000000001"],
        data: "0x",
        block_number: 100,
        transaction_hash: "0xabc",
        log_index: 0,
        chain_id: 1
      }

      decoded = Decoder.decode_log(decoder, event_log)

      assert decoded.event_name == nil
      assert decoded.decoded_params == nil
    end

    test "handles event log with no topics" do
      decoder = Decoder.new(@transfer_abi)

      event_log = %EventLog{
        address: "0xdead",
        topics: [],
        data: "0x",
        block_number: 100,
        transaction_hash: "0xabc",
        log_index: 0,
        chain_id: 1
      }

      decoded = Decoder.decode_log(decoder, event_log)
      assert decoded.event_name == nil
    end

    test "handles event log with nil topics" do
      decoder = Decoder.new(@transfer_abi)

      event_log = %EventLog{
        address: "0xdead",
        topics: nil,
        data: "0x",
        block_number: 100,
        transaction_hash: "0xabc",
        log_index: 0,
        chain_id: 1
      }

      decoded = Decoder.decode_log(decoder, event_log)
      assert decoded.event_name == nil
    end
  end

  describe "decode_logs/2" do
    test "decodes a batch of logs" do
      decoder = Decoder.new(@transfer_abi)
      transfer_topic = Decoder.event_topic("Transfer(address,address,uint256)")
      from_addr = "0x000000000000000000000000ab5801a7d398351b8be11c439e05c5b3259aec9b"
      to_addr = "0x0000000000000000000000004838b106fce9647bdf1e7877bf73ce8b0bad5f97"

      logs = [
        %EventLog{
          address: "0xdead",
          topics: [transfer_topic, from_addr, to_addr],
          data: "0x00000000000000000000000000000000000000000000000000000000000f4240",
          block_number: 100,
          transaction_hash: "0xabc",
          log_index: 0,
          chain_id: 1
        },
        %EventLog{
          address: "0xdead",
          topics: [transfer_topic, to_addr, from_addr],
          data: "0x0000000000000000000000000000000000000000000000000000000000001000",
          block_number: 101,
          transaction_hash: "0xdef",
          log_index: 1,
          chain_id: 1
        }
      ]

      decoded = Decoder.decode_logs(decoder, logs)

      assert length(decoded) == 2
      assert Enum.all?(decoded, &(&1.event_name == "Transfer"))
    end
  end

  describe "known_events/1" do
    test "lists event names from decoder" do
      decoder = Decoder.new(@mixed_abi)
      events = Decoder.known_events(decoder)

      assert "Approval" in events
      assert "Transfer" in events
      assert length(events) == 2
    end

    test "returns empty list for empty decoder" do
      decoder = Decoder.new([])
      assert Decoder.known_events(decoder) == []
    end
  end
end
