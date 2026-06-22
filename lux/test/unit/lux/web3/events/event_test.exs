defmodule Lux.Web3.Events.EventTest do
  use UnitAPICase, async: true
  alias Lux.Web3.Events.Event

  describe "from_raw/2" do
    test "converts raw log map to Event struct" do
      raw = %{
        "address" => "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
        "topics" => [
          "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          "0x0000000000000000000000000000000000000000000000000000000000000001"
        ],
        "data" => "0x",
        "blockNumber" => "0xc3d1a4",
        "timeStamp" => "628736144",
        "gasPrice" => "94000000000",
        "gasUsed" => "65715",
        "logIndex" => "142",
        "transactionHash" => "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649",
        "transactionIndex" => "93"
      }

      event = Event.from_raw(raw, 1)
      assert event.chain_id == 1
      assert event.contract_address == "0xbd3531da5cf5857e7cfaa92426877b022e612cf8"
      assert event.topic0 == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      assert length(event.topics) == 2
      assert event.block_number == 12_732_196
      assert event.timestamp == 628_736_144
      assert event.log_index == 142
      assert event.transaction_hash == "0x9e1b4e83517b5773e64e80b7b59bf5a850c7bf52d45d56a6e9e6d3846e77c649"
    end

    test "handles decimal block numbers" do
      raw = %{
        "address" => "0x1234567890123456789012345678901234567890",
        "topics" => [],
        "data" => "0x",
        "blockNumber" => "12345678",
        "timeStamp" => "1234567890",
        "logIndex" => "0",
        "transactionHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
        "transactionIndex" => "0"
      }
      event = Event.from_raw(raw, 1)
      assert event.block_number == 12_345_678
    end

    test "handles missing fields gracefully" do
      event = Event.from_raw(%{}, 1)
      assert event.contract_address == ""
      assert event.block_number == 0
      assert event.topic0 == ""
    end
  end

  describe "parse_hex_or_dec/1" do
    test "parses hex strings" do
      assert Event.parse_hex_or_dec("0x1a2b3c") == 1_715_068
    end

    test "parses decimal strings" do
      assert Event.parse_hex_or_dec("12345678") == 12_345_678
    end

    test "handles zero" do
      assert Event.parse_hex_or_dec("0x0") == 0
      assert Event.parse_hex_or_dec("0") == 0
    end

    test "handles invalid input" do
      assert Event.parse_hex_or_dec("") == 0
      assert Event.parse_hex_or_dec("invalid") == 0
    end
  end

  describe "matches_topic_filter?/2" do
    test "matches when topic0 equals filter" do
      event = %Event{topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"}
      assert Event.matches_topic_filter?(event, ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"])
      refute Event.matches_topic_filter?(event, ["0x0000000000000000000000000000000000000000000000000000000000000000"])
    end

    test "matches :any filter" do
      event = %Event{topic0: "0xabc"}
      assert Event.matches_topic_filter?(event, [:any])
    end
  end

  describe "to_map/1" do
    test "serializes event to map" do
      event = %Event{chain_id: 1, contract_address: "0x123", block_number: 100}
      map = Event.to_map(event)
      assert map.chain_id == 1
      assert map.contract_address == "0x123"
      assert map.block_number == 100
    end
  end
end
