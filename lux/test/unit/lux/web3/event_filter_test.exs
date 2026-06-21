defmodule Lux.Web3.EventFilterTest do
  use UnitCase, async: true

  alias Lux.Web3.EventFilter

  @transfer_sig "Transfer(address,address,uint256)"
  @approval_sig "Approval(address,address,uint256)"
  @usdt_address "0xdAC17F958D2ee523a2206206994597C13D831ec7"

  describe "encode_event_signature/1" do
    test "encodes Transfer event signature to keccak256 topic hash" do
      topic = EventFilter.encode_event_signature(@transfer_sig)
      assert String.starts_with?(topic, "0x")
      # Keccak-256 hash is 32 bytes = 64 hex chars + "0x" prefix
      assert String.length(topic) == 66
    end

    test "encodes Approval event signature" do
      topic = EventFilter.encode_event_signature(@approval_sig)
      assert String.starts_with?(topic, "0x")
      assert String.length(topic) == 66
    end

    test "different signatures produce different hashes" do
      transfer_topic = EventFilter.encode_event_signature(@transfer_sig)
      approval_topic = EventFilter.encode_event_signature(@approval_sig)
      assert transfer_topic != approval_topic
    end

    test "same signature always produces same hash" do
      topic1 = EventFilter.encode_event_signature(@transfer_sig)
      topic2 = EventFilter.encode_event_signature(@transfer_sig)
      assert topic1 == topic2
    end
  end

  describe "parse_signature/1" do
    test "parses a valid event signature" do
      {:ok, parsed} = EventFilter.parse_signature(@transfer_sig)
      assert parsed.name == "Transfer"
      assert parsed.param_types == ["address", "address", "uint256"]
    end

    test "parses single-param signature" do
      {:ok, parsed} = EventFilter.parse_signature("Deposit(uint256)")
      assert parsed.name == "Deposit"
      assert parsed.param_types == ["uint256"]
    end

    test "parses no-param signature" do
      {:ok, parsed} = EventFilter.parse_signature("Paused()")
      assert parsed.name == "Paused"
      assert parsed.param_types == []
    end

    test "returns error for invalid signature format" do
      {:error, msg} = EventFilter.parse_signature("not a valid sig")
      assert String.contains?(msg, "Invalid event signature format")
    end
  end

  describe "build_filter/1" do
    test "builds filter with contract address and event signatures" do
      {:ok, filter} =
        EventFilter.build_filter(%{
          contract_address: @usdt_address,
          event_signatures: [@transfer_sig],
          from_block: "0x0",
          to_block: "latest"
        })

      assert filter["address"] == @usdt_address
      assert filter["fromBlock"] == "0x0"
      assert filter["toBlock"] == "latest"
      assert is_list(filter["topics"])
      # First topic should be the encoded Transfer signature
      [topic0 | _] = filter["topics"]
      assert String.starts_with?(topic0, "0x")
    end

    test "builds filter with multiple event signatures" do
      {:ok, filter} =
        EventFilter.build_filter(%{
          contract_address: @usdt_address,
          event_signatures: [@transfer_sig, @approval_sig]
        })

      [topic0 | _] = filter["topics"]
      # Multiple signatures => topic0 should be a list
      assert is_list(topic0)
      assert length(topic0) == 2
    end

    test "builds filter with integer block numbers" do
      {:ok, filter} =
        EventFilter.build_filter(%{
          contract_address: @usdt_address,
          from_block: 1000,
          to_block: 2000
        })

      assert String.downcase(filter["fromBlock"]) == "0x3e8"
      assert String.downcase(filter["toBlock"]) == "0x7d0"
    end

    test "uses latest as default for from/to blocks" do
      {:ok, filter} =
        EventFilter.build_filter(%{
          contract_address: @usdt_address
        })

      assert filter["fromBlock"] == "latest"
      assert filter["toBlock"] == "latest"
    end

    test "returns error without contract_address" do
      {:error, msg} = EventFilter.build_filter(%{})
      assert msg == "contract_address is required"
    end
  end

  describe "build_subscription_filter/1" do
    test "builds subscription filter with address and topics" do
      {:ok, filter} =
        EventFilter.build_subscription_filter(%{
          contract_address: @usdt_address,
          event_signatures: [@transfer_sig]
        })

      assert filter["address"] == @usdt_address
      assert is_list(filter["topics"])
      refute Map.has_key?(filter, "fromBlock")
      refute Map.has_key?(filter, "toBlock")
    end

    test "returns error without contract_address" do
      {:error, _} = EventFilter.build_subscription_filter(%{})
    end
  end

  describe "decode_log/1" do
    test "decodes a valid log entry" do
      log = sample_log()
      {:ok, decoded} = EventFilter.decode_log(log)

      assert decoded.event_signature == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      assert decoded.contract_address == @usdt_address
      assert decoded.block_number == 18_000_000
      assert decoded.transaction_hash == "0xabc123"
      assert decoded.log_index == 42
      assert is_list(decoded.topics)
      assert length(decoded.topics) == 2
      assert decoded.removed == false
    end

    test "decodes indexed topics with address and integer representations" do
      log = sample_log()
      {:ok, decoded} = EventFilter.decode_log(log)

      [topic1, _topic2] = decoded.topics
      assert Map.has_key?(topic1, :raw)
      assert Map.has_key?(topic1, :as_address)
      assert Map.has_key?(topic1, :as_integer)
    end

    test "decodes data into 32-byte segments" do
      log = sample_log()
      {:ok, decoded} = EventFilter.decode_log(log)

      assert is_list(decoded.decoded_data)
      Enum.each(decoded.decoded_data, fn segment ->
        assert String.starts_with?(segment, "0x")
      end)
    end

    test "returns error for log with empty topics" do
      {:error, msg} = EventFilter.decode_log(%{"topics" => []})
      assert String.contains?(msg, "anonymous event")
    end

    test "returns error for invalid log format" do
      {:error, _} = EventFilter.decode_log(%{})
    end
  end

  describe "decode_logs/1" do
    test "decodes a batch of log entries" do
      logs = [sample_log(), sample_log()]
      decoded = EventFilter.decode_logs(logs)
      assert length(decoded) == 2
    end

    test "filters out invalid logs" do
      logs = [sample_log(), %{"topics" => []}, sample_log()]
      decoded = EventFilter.decode_logs(logs)
      assert length(decoded) == 2
    end

    test "returns empty list for empty input" do
      assert EventFilter.decode_logs([]) == []
    end
  end

  describe "matches?/2" do
    test "matches event with matching signature" do
      {:ok, event} = EventFilter.decode_log(sample_log())

      filter = %{
        event_signatures: [@transfer_sig]
      }

      assert EventFilter.matches?(event, filter)
    end

    test "does not match event with different signature" do
      {:ok, event} = EventFilter.decode_log(sample_log())

      filter = %{
        event_signatures: [@approval_sig]
      }

      refute EventFilter.matches?(event, filter)
    end

    test "matches event with matching contract address" do
      {:ok, event} = EventFilter.decode_log(sample_log())

      filter = %{
        contract_address: @usdt_address
      }

      assert EventFilter.matches?(event, filter)
    end

    test "matches event within block range" do
      {:ok, event} = EventFilter.decode_log(sample_log())

      filter = %{
        min_block: 17_000_000,
        max_block: 19_000_000
      }

      assert EventFilter.matches?(event, filter)
    end

    test "does not match event outside block range" do
      {:ok, event} = EventFilter.decode_log(sample_log())

      filter = %{
        min_block: 19_000_000,
        max_block: 20_000_000
      }

      refute EventFilter.matches?(event, filter)
    end

    test "matches everything with empty filter" do
      {:ok, event} = EventFilter.decode_log(sample_log())
      assert EventFilter.matches?(event, %{})
    end
  end

  # ── Test Helpers ─────────────────────────────────────────────────────

  defp sample_log do
    transfer_topic = EventFilter.encode_event_signature(@transfer_sig)

    %{
      "address" => @usdt_address,
      "topics" => [
        transfer_topic,
        "0x000000000000000000000000" <> "d8da6bf26964af9d7eed9e03e53415d37aa96045",
        "0x000000000000000000000000" <> "a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
      ],
      "data" => "0x0000000000000000000000000000000000000000000000000000000005f5e100",
      "blockNumber" => "0x112a880",
      "transactionHash" => "0xabc123",
      "logIndex" => "0x2a",
      "blockHash" => "0xdef456",
      "transactionIndex" => "0x5",
      "removed" => false
    }
  end
end
