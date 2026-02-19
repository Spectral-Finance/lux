defmodule Lux.EventMonitor.FilterTest do
  use UnitCase, async: true

  alias Lux.EventMonitor.EventLog
  alias Lux.EventMonitor.Filter

  @transfer_log %EventLog{
    address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    topics: [
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      "0x000000000000000000000000ab5801a7d398351b8be11c439e05c5b3259aec9b"
    ],
    data: "0x",
    block_number: 18_000_000,
    transaction_hash: "0xabc",
    log_index: 0,
    chain_id: 1,
    event_name: "Transfer",
    decoded_params: %{
      "from" => "0xab5801a7d398351b8be11c439e05c5b3259aec9b",
      "to" => "0x4838b106fce9647bdf1e7877bf73ce8b0bad5f97",
      "value" => 1_000_000
    }
  }

  @approval_log %EventLog{
    address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    topics: ["0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"],
    data: "0x",
    block_number: 18_001_000,
    transaction_hash: "0xdef",
    log_index: 1,
    chain_id: 1,
    event_name: "Approval",
    decoded_params: %{
      "owner" => "0xab5801a7d398351b8be11c439e05c5b3259aec9b",
      "spender" => "0x4838b106fce9647bdf1e7877bf73ce8b0bad5f97",
      "value" => 999_999_999
    }
  }

  @polygon_log %EventLog{
    address: "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
    topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],
    data: "0x",
    block_number: 50_000_000,
    transaction_hash: "0xpoly",
    log_index: 0,
    chain_id: 137,
    event_name: "Transfer",
    decoded_params: %{"value" => 500}
  }

  describe "matches?/2" do
    test "matches by address (case insensitive)" do
      assert Filter.matches?(@transfer_log, %{address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"})
    end

    test "does not match wrong address" do
      refute Filter.matches?(@transfer_log, %{address: "0x0000000000000000000000000000000000000000"})
    end

    test "matches by event name (string)" do
      assert Filter.matches?(@transfer_log, %{event_name: "Transfer"})
      refute Filter.matches?(@transfer_log, %{event_name: "Approval"})
    end

    test "matches by event name (list)" do
      assert Filter.matches?(@transfer_log, %{event_name: ["Transfer", "Approval"]})
      refute Filter.matches?(@transfer_log, %{event_name: ["Approval", "Mint"]})
    end

    test "matches by topics" do
      assert Filter.matches?(@transfer_log, %{
        topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef", nil]
      })
    end

    test "matches by chain_id" do
      assert Filter.matches?(@transfer_log, %{chain_id: 1})
      refute Filter.matches?(@transfer_log, %{chain_id: 137})
    end

    test "matches by block range" do
      assert Filter.matches?(@transfer_log, %{from_block: 17_999_999, to_block: 18_000_001})
      refute Filter.matches?(@transfer_log, %{from_block: 18_000_001})
      refute Filter.matches?(@transfer_log, %{to_block: 17_999_999})
    end

    test "matches by decoded params - exact value" do
      assert Filter.matches?(@transfer_log, %{params: %{"value" => 1_000_000}})
      refute Filter.matches?(@transfer_log, %{params: %{"value" => 999}})
    end

    test "matches by decoded params - greater than" do
      assert Filter.matches?(@transfer_log, %{params: %{"value" => {:gt, 999_999}}})
      refute Filter.matches?(@transfer_log, %{params: %{"value" => {:gt, 1_000_000}}})
    end

    test "matches by decoded params - less than" do
      assert Filter.matches?(@transfer_log, %{params: %{"value" => {:lt, 1_000_001}}})
      refute Filter.matches?(@transfer_log, %{params: %{"value" => {:lt, 1_000_000}}})
    end

    test "matches by decoded params - gte and lte" do
      assert Filter.matches?(@transfer_log, %{params: %{"value" => {:gte, 1_000_000}}})
      assert Filter.matches?(@transfer_log, %{params: %{"value" => {:lte, 1_000_000}}})
      refute Filter.matches?(@transfer_log, %{params: %{"value" => {:gte, 1_000_001}}})
      refute Filter.matches?(@transfer_log, %{params: %{"value" => {:lte, 999_999}}})
    end

    test "matches by decoded params - in list" do
      assert Filter.matches?(@transfer_log, %{params: %{"value" => {:in, [1_000_000, 2_000_000]}}})
      refute Filter.matches?(@transfer_log, %{params: %{"value" => {:in, [1, 2, 3]}}})
    end

    test "matches by decoded params - not equal" do
      assert Filter.matches?(@transfer_log, %{params: %{"value" => {:neq, 0}}})
      refute Filter.matches?(@transfer_log, %{params: %{"value" => {:neq, 1_000_000}}})
    end

    test "matches by decoded params - regex" do
      assert Filter.matches?(@transfer_log, %{params: %{"from" => {:regex, ~r/^0xab58/}}})
      refute Filter.matches?(@transfer_log, %{params: %{"from" => {:regex, ~r/^0x0000/}}})
    end

    test "matches by custom predicate" do
      assert Filter.matches?(@transfer_log, %{
        predicate: fn log -> log.block_number > 17_000_000 end
      })

      refute Filter.matches?(@transfer_log, %{
        predicate: fn log -> log.block_number > 19_000_000 end
      })
    end

    test "matches with multiple criteria (AND)" do
      assert Filter.matches?(@transfer_log, %{
        event_name: "Transfer",
        chain_id: 1,
        from_block: 17_000_000
      })

      refute Filter.matches?(@transfer_log, %{
        event_name: "Transfer",
        chain_id: 137
      })
    end

    test "returns false for nil decoded_params with params filter" do
      log = %EventLog{@transfer_log | decoded_params: nil}
      refute Filter.matches?(log, %{params: %{"value" => 1_000_000}})
    end

    test "matches empty filter (everything matches)" do
      assert Filter.matches?(@transfer_log, %{})
    end

    test "returns false for non-EventLog input" do
      refute Filter.matches?("not a log", %{event_name: "Transfer"})
    end
  end

  describe "filter_logs/2" do
    @all_logs [@transfer_log, @approval_log, @polygon_log]

    test "filters by event name" do
      result = Filter.filter_logs(@all_logs, %{event_name: "Transfer"})
      assert length(result) == 2
      assert Enum.all?(result, &(&1.event_name == "Transfer"))
    end

    test "filters by chain_id" do
      result = Filter.filter_logs(@all_logs, %{chain_id: 137})
      assert length(result) == 1
      assert hd(result).chain_id == 137
    end

    test "filters by address and event name" do
      result = Filter.filter_logs(@all_logs, %{
        address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        event_name: "Transfer"
      })
      assert length(result) == 1
    end

    test "returns empty list when nothing matches" do
      result = Filter.filter_logs(@all_logs, %{event_name: "NonExistent"})
      assert result == []
    end

    test "empty filter returns all logs" do
      result = Filter.filter_logs(@all_logs, %{})
      assert length(result) == 3
    end
  end

  describe "all_of/1" do
    test "combines filters with AND logic" do
      combined = Filter.all_of([
        %{event_name: "Transfer"},
        %{chain_id: 1}
      ])

      assert Filter.matches?(@transfer_log, combined)
      refute Filter.matches?(@polygon_log, combined)
    end
  end

  describe "any_of/1" do
    test "combines filters with OR logic" do
      combined = Filter.any_of([
        %{event_name: "Approval"},
        %{chain_id: 137}
      ])

      assert Filter.matches?(@approval_log, combined)
      assert Filter.matches?(@polygon_log, combined)
      refute Filter.matches?(@transfer_log, combined)
    end
  end
end
