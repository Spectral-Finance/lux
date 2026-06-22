defmodule Lux.Web3.Events.DecoderTest do
  use UnitAPICase, async: true
  alias Lux.Web3.Events.Decoder

  describe "event_signature_to_topic/1" do
    test "computes correct keccak256 for Transfer" do
      topic = Decoder.event_signature_to_topic("Transfer(address,address,uint256)")
      assert topic == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    end

    test "computes correct keccak256 for Approval" do
      topic = Decoder.event_signature_to_topic("Approval(address,address,uint256)")
      assert topic == "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
    end

    test "handles empty string" do
      topic = Decoder.event_signature_to_topic("")
      assert String.starts_with?(topic, "0x")
      assert String.length(topic) == 66
    end
  end

  describe "decode_log_param/2" do
    test "decodes address type" do
      result = Decoder.decode_log_param("address", "0x0000000000000000000000001234567890123456789012345678901234567890")
      assert result == "0x1234567890123456789012345678901234567890"
    end

    test "decodes uint256" do
      result = Decoder.decode_log_param("uint256", "0xde0b6b3a7640000")
      assert result == 1_000_000_000_000_000_000
    end
  end

  describe "parse_abi_events/1" do
    test "extracts event entries from ABI" do
      abi_json = """
      [
        {"type": "function", "name": "transfer"},
        {"type": "event", "name": "Transfer", "inputs": [{"name": "from", "type": "address", "indexed": true}, {"name": "to", "type": "address", "indexed": true}, {"name": "value", "type": "uint256", "indexed": false}]},
        {"type": "event", "name": "Approval", "inputs": [{"name": "owner", "type": "address", "indexed": true}]}
      ]
      """
      events = Decoder.parse_abi_events(abi_json)
      assert length(events) == 2
      assert hd(events)["name"] == "Transfer"
      assert hd(events)[:signature] == "Transfer(address,address,uint256)"
    end

    test "returns empty list for invalid JSON" do
      assert Decoder.parse_abi_events("not json") == []
    end
  end

  describe "find_abi_entry/2" do
    test "finds matching event by signature" do
      abi = [%{"type" => "event", "name" => "Transfer", "inputs" => [%{"name" => "from", "type" => "address", "indexed" => true}, %{"name" => "to", "type" => "address", "indexed" => true}, %{"name" => "value", "type" => "uint256", "indexed" => false}]}]
      entry = Decoder.find_abi_entry(abi, "Transfer(address,address,uint256)")
      assert entry == hd(abi)
    end

    test "returns nil for non-matching signature" do
      abi = [%{"type" => "event", "name" => "Transfer", "inputs" => []}]
      refute Decoder.find_abi_entry(abi, "Approval(address,address,uint256)")
    end
  end
end
