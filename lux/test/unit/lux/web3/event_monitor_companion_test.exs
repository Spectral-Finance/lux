defmodule Lux.Web3.EventMonitorCompanionTest do
  use UnitCase, async: true

  alias Lux.Web3.EventMonitor
  alias Lux.Web3.EventMonitor.Error

  @contract "0x1234567890123456789012345678901234567890"

  @abi %{
    "name" => "Transfer",
    "inputs" => [
      %{"name" => "from", "type" => "address", "indexed" => true},
      %{"name" => "to", "type" => "address", "indexed" => true},
      %{"name" => "value", "type" => "uint256", "indexed" => false}
    ]
  }

  defp selector, do: EventMonitor.event_selector(@abi)

  defp pad64(hex), do: String.pad_leading(hex, 64, "0")

  defp transfer_log(selector, from, to, value, block \\ 1) do
    %{
      "topics" =>
        [
          "0x" <> Base.encode16(selector.method_id),
          "0x" <> pad64(from),
          "0x" <> pad64(to)
        ],
      "data" => "0x" <> pad64(Integer.to_string(value, 16)),
      "blockNumber" => Integer.to_string(block, 16),
      "logIndex" => "0x0",
      "transactionIndex" => "0x0",
      "blockHash" => "0x" <> String.duplicate("00", 32),
      "transactionHash" => "0x" <> String.duplicate("11", 32),
      "address" => @contract,
      "removed" => false
    }
  end

  setup do
    {:ok, pid} = EventMonitor.start_link()
    {:ok, monitor: pid}
  end

  # --------------------------------------------------------------------------
  # Empty inputs (no silent state corruption)
  # --------------------------------------------------------------------------

  describe "empty webhook urls" do
    test "rejects empty add_webhook url and leaves state untouched", %{monitor: pid} do
      assert match?(
               {:error, %Error{code: :invalid_argument, field: :url, reason: :empty}},
               EventMonitor.add_webhook(pid, "")
             )

      assert {:ok, []} = EventMonitor.webhooks(pid)
    end

    test "rejects empty remove_webhook url", %{monitor: pid} do
      assert match?(
               {:error, %Error{code: :invalid_argument, field: :url, reason: :empty}},
               EventMonitor.remove_webhook(pid, "")
             )
    end

    test "rejects empty notify_webhook url without crashing", %{monitor: pid} do
      event = %EventMonitor.Event{
        event_name: "Transfer",
        received_at: DateTime.utc_now()
      }

      assert match?(
               {:error, %Error{code: :invalid_argument, field: :url, reason: :empty}},
               EventMonitor.notify_webhook("", event)
             )
    end
  end

  # --------------------------------------------------------------------------
  # Boundary values (half-open intervals evaluated strictly)
  # --------------------------------------------------------------------------

  describe "block boundaries" do
    test "processes and retrieves an event at block 0", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer", from_block: 0)

      log = transfer_log(selector(), "deadbeef", "cafebab", 7, 0)
      {:ok, event} = EventMonitor.process_event(pid, @contract, selector(), log)

      assert event.block_number == 0

      {:ok, events} = EventMonitor.events(pid, from_block: 0)
      assert length(events) == 1
      assert hd(events).block_number == 0
    end

    test "from_block excludes events strictly below the boundary", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")

      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "a", "b", 1, 0))
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "c", "d", 2, 5))

      {:ok, events} = EventMonitor.events(pid, from_block: 5)
      assert length(events) == 1
      assert hd(events).block_number == 5

      {:ok, events} = EventMonitor.events(pid, from_block: 6)
      assert events == []
    end

    test "to_block is inclusive at exact boundary", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")

      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "a", "b", 1, 5))
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "c", "d", 2, 10))

      {:ok, events} = EventMonitor.events(pid, to_block: 5)
      assert length(events) == 1
      assert hd(events).block_number == 5
    end
  end

  # --------------------------------------------------------------------------
  # Negative / malformed inputs (typed errors, no crashes)
  # --------------------------------------------------------------------------

  describe "negative inputs" do
    test "rejects whitespace-only contract address", %{monitor: pid} do
      assert match?(
               {:error, %Error{code: :invalid_argument, field: :contract_address}},
               EventMonitor.subscribe(pid, "   ", "Transfer")
             )
    end

    test "event_selector rejects abi map missing name with a typed error", %{monitor: pid} do
      assert match?(
               {:error, %Error{code: :invalid_argument, field: :event_abi}},
               EventMonitor.event_selector(%{})
             )
    end

    test "event_selector rejects non-map abi with a typed error", %{monitor: _pid} do
      assert match?(
               {:error, %Error{code: :invalid_argument, field: :event_abi}},
               EventMonitor.event_selector(:not_a_map)
             )
    end

    test "rejects a malformed selector with a typed error instead of crashing", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")

      result = EventMonitor.process_event(pid, @contract, %{}, transfer_log(selector(), "a", "b", 1))

      assert match?(
               {:error, %Error{code: :invalid_argument, field: :selector, reason: :malformed}},
               result
             )
    end
  end
end
