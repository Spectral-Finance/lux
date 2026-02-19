defmodule Lux.EventMonitor.EventLogTest do
  use UnitCase, async: true

  alias Lux.EventMonitor.EventLog

  @raw_log %{
    "address" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    "topics" => [
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      "0x000000000000000000000000ab5801a7d398351b8be11c439e05c5b3259aec9b",
      "0x0000000000000000000000004838b106fce9647bdf1e7877bf73ce8b0bad5f97"
    ],
    "data" => "0x00000000000000000000000000000000000000000000000000000000000f4240",
    "blockNumber" => "0x112A880",
    "blockHash" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
    "transactionHash" => "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "transactionIndex" => "0x5",
    "logIndex" => "0xa",
    "timeStamp" => "1700000000",
    "removed" => false
  }

  describe "from_raw/2" do
    test "parses a raw log map with hex values" do
      log = EventLog.from_raw(@raw_log)

      assert log.address == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
      assert length(log.topics) == 3
      assert log.data == "0x00000000000000000000000000000000000000000000000000000000000f4240"
      # 0x112A880 = 18,040,960
      assert log.block_number == 0x112A880
      assert log.transaction_index == 5
      assert log.log_index == 10
      assert log.timestamp == 1_700_000_000
      assert log.removed == false
      assert log.chain_id == 1
    end

    test "accepts chain_id option" do
      log = EventLog.from_raw(@raw_log, chain_id: 137)
      assert log.chain_id == 137
    end

    test "handles missing fields with defaults" do
      log = EventLog.from_raw(%{})

      assert log.address == ""
      assert log.topics == []
      assert log.data == "0x"
      assert log.block_number == 0
      assert log.transaction_hash == ""
      assert log.log_index == 0
      assert log.chain_id == 1
      assert log.removed == false
    end

    test "handles integer block numbers" do
      raw = %{"blockNumber" => 12345}
      log = EventLog.from_raw(raw)
      assert log.block_number == 12345
    end

    test "handles decimal string block numbers" do
      raw = %{"blockNumber" => "12345"}
      log = EventLog.from_raw(raw)
      assert log.block_number == 12345
    end

    test "handles nil values gracefully" do
      raw = %{"blockNumber" => nil, "logIndex" => nil, "timeStamp" => nil}
      log = EventLog.from_raw(raw)
      assert log.block_number == nil
      assert log.log_index == nil
      assert log.timestamp == nil
    end
  end

  describe "event_signature/1" do
    test "returns topic0 when topics exist" do
      log = EventLog.from_raw(@raw_log)
      assert EventLog.event_signature(log) == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    end

    test "returns nil when topics are empty" do
      log = %EventLog{topics: []}
      assert EventLog.event_signature(log) == nil
    end
  end

  describe "unique_id/1" do
    test "combines transaction hash and log index" do
      log = EventLog.from_raw(@raw_log)
      assert EventLog.unique_id(log) == "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef:10"
    end
  end

  describe "matches_topics?/2" do
    test "matches exact topic values" do
      log = EventLog.from_raw(@raw_log)

      assert EventLog.matches_topics?(log, [
        "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      ])
    end

    test "matches with nil wildcards" do
      log = EventLog.from_raw(@raw_log)

      assert EventLog.matches_topics?(log, [
        "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        nil,
        "0x0000000000000000000000004838b106fce9647bdf1e7877bf73ce8b0bad5f97"
      ])
    end

    test "does not match wrong topic values" do
      log = EventLog.from_raw(@raw_log)

      refute EventLog.matches_topics?(log, [
        "0x0000000000000000000000000000000000000000000000000000000000000000"
      ])
    end

    test "all-nil filter matches everything" do
      log = EventLog.from_raw(@raw_log)
      assert EventLog.matches_topics?(log, [nil, nil, nil])
    end

    test "handles non-list filter" do
      log = EventLog.from_raw(@raw_log)
      assert EventLog.matches_topics?(log, "not a list")
    end
  end
end
