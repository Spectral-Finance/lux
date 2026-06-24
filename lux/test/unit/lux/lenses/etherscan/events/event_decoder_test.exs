defmodule Lux.Lenses.Etherscan.Events.EventDecoderTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.Events.EventDecoder

  @transfer_abi [
    %{
      "anonymous" => false,
      "inputs" => [
        %{"indexed" => true, "name" => "from", "type" => "address"},
        %{"indexed" => true, "name" => "to", "type" => "address"},
        %{"indexed" => false, "name" => "value", "type" => "uint256"}
      ],
      "name" => "Transfer",
      "type" => "event"
    }
  ]

  @transfer_sig "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  describe "compute_event_signature/2" do
    test "computes correct signature for Transfer event" do
      inputs = @transfer_abi |> List.first() |> Map.get("inputs")
      name = @transfer_abi |> List.first() |> Map.get("name")
      result = EventDecoder.compute_event_signature(name, inputs)
      assert result == @transfer_sig
    end

    test "computes correct signature using string form" do
      result = EventDecoder.compute_event_signature("Transfer(address,address,uint256)")
      assert result == @transfer_sig
    end
  end

  describe "find_event_by_signature/2" do
    test "finds event by known signature" do
      assert {:ok, event} = EventDecoder.find_event_by_signature(@transfer_abi, @transfer_sig)
      assert event["name"] == "Transfer"
    end

    test "returns error for unknown signature" do
      assert :error = EventDecoder.find_event_by_signature(@transfer_abi, "0x0000000000000000000000000000000000000000000000000000000000000000")
    end
  end

  describe "decode_event/4" do
    test "decodes Transfer event with ABI" do
      topics = [
        @transfer_sig,
        "0x000000000000000000000000a79e63e78eec28741e711f89a672a4c40876ebf3",
        "0x000000000000000000000000b4e16d0168e52d35cacd2c6185b44281ec28c9dc"
      ]

      assert {:ok, decoded} = EventDecoder.decode_event(@transfer_abi, @transfer_sig, topics, "0x0000000000000000000000000000000000000000000000000000000005f5e100")
      assert decoded["name"] == "Transfer"
      assert decoded["signature"] == @transfer_sig
      assert length(decoded["indexed"]) == 2
      assert length(decoded["non_indexed"]) == 1
      assert decoded["anonymous"] == false
    end

    test "returns error for unknown signature" do
      result = EventDecoder.decode_event(@transfer_abi, "0x0000000000000000000000000000000000000000000000000000000000000000", [], "0x")
      assert {:error, _} = result
    end
  end

  describe "decode_events/2" do
    test "decodes mixed events" do
      logs = [
        %{"address" => "0xdac17f958d2ee523a2206206994597c13d831ec7", "topics" => [@transfer_sig, "0xaaa", "0xbbb"], "data" => "0x1234"},
        %{"address" => "0xdac17f958d2ee523a2206206994597c13d831ec7", "topics" => ["0x0000000000000000000000000000000000000000000000000000000000000000"], "data" => "0x"}
      ]

      result = EventDecoder.decode_events(logs, @transfer_abi)
      assert length(result) == 2
      assert result |> Enum.at(0) |> Map.get("decoded") |> Map.get("name") == "Transfer"
      assert result |> Enum.at(1) |> Map.get("decoded") |> Map.get("raw") == true
    end

    test "handles empty logs" do
      assert EventDecoder.decode_events([], @transfer_abi) == []
    end
  end
end
