defmodule Lux.Web3.EventMonitor.DecoderTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.EventMonitor.Decoder

  describe "decode/3 for standard ERC-20 Transfer" do
    test "decodes indexed from/to and data value" do
      t0 = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      from_topic = "0x0000000000000000000000001111111111111111111111111111111111111111"
      to_topic = "0x0000000000000000000000002222222222222222222222222222222222222222"
      # Value = 1,000,000,000 (0x3b9aca00)
      data = "0x000000000000000000000000000000000000000000000000000000003b9aca00"

      {:ok, decoded} = Decoder.decode([t0, from_topic, to_topic], data)

      assert decoded[:_event_type] == :transfer
      assert decoded[:from] == "0x1111111111111111111111111111111111111111"
      assert decoded[:to] == "0x2222222222222222222222222222222222222222"
      assert decoded[:value] == 1_000_000_000
    end
  end

  describe "decode/3 for Uniswap V3 Swap" do
    test "decodes sender, recipient, and amount parameters" do
      t0 = "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67"
      sender_t = "0x000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      recipient_t = "0x000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

      # 5 words in data: amount0, amount1, sqrtPriceX96, liquidity, tick
      w1 = String.duplicate("0", 63) <> "1"
      w2 = String.duplicate("0", 63) <> "2"
      w3 = String.duplicate("0", 63) <> "3"
      w4 = String.duplicate("0", 63) <> "4"
      w5 = String.duplicate("0", 63) <> "5"
      data = "0x" <> w1 <> w2 <> w3 <> w4 <> w5

      {:ok, decoded} = Decoder.decode([t0, sender_t, recipient_t], data)

      assert decoded[:_event_type] == :uniswap_v3_swap
      assert decoded[:sender] == "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      assert decoded[:recipient] == "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      assert decoded[:amount0] == 1
      assert decoded[:amount1] == 2
      assert decoded[:sqrtPriceX96] == 3
    end
  end

  describe "topic_to_address/1 and parse_uint256/1" do
    test "extracts 20-byte address from 32-byte topic" do
      topic = "0x000000000000000000000000abcdef1234567890abcdef1234567890abcdef12"
      assert Decoder.topic_to_address(topic) == "0xabcdef1234567890abcdef1234567890abcdef12"
    end

    test "parses uint256 hex string" do
      assert Decoder.parse_uint256("0xff") == 255
      assert Decoder.parse_uint256("0x10") == 16
      assert Decoder.parse_uint256(nil) == 0
    end
  end
end
