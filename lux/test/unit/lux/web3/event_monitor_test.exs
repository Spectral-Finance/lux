defmodule Lux.Web3.EventMonitorTest do
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
  # Happy path
  # --------------------------------------------------------------------------

  describe "subscription management" do
    test "subscribes to a contract event and returns an id", %{monitor: pid} do
      {:ok, sub_id} =
        EventMonitor.subscribe(pid, @contract, "Transfer", event_abi: @abi)

      assert is_binary(sub_id)
      assert sub_id =~ ~r/^\d+$/

      {:ok, sub} = EventMonitor.subscription(pid, sub_id)
      assert sub.contract_address == @contract
      assert sub.event_name == "Transfer"
      assert sub.active == true

      {:ok, subs} = EventMonitor.list_subscriptions(pid)
      assert length(subs) == 1
      assert hd(subs).id == sub_id
    end

    test "is idempotent for the same (contract, event) pair", %{monitor: pid} do
      {:ok, first} = EventMonitor.subscribe(pid, @contract, "Transfer")
      {:ok, second} = EventMonitor.subscribe(pid, @contract, "Transfer")

      assert first == second
      {:ok, subs} = EventMonitor.list_subscriptions(pid)
      assert length(subs) == 1
    end

    test "unsubscribes an existing subscription", %{monitor: pid} do
      {:ok, sub_id} = EventMonitor.subscribe(pid, @contract, "Transfer")
      assert {:ok, sub_id} = EventMonitor.unsubscribe(pid, sub_id)
      assert {:error, :not_found} = EventMonitor.subscription(pid, sub_id)
    end
  end

  describe "event processing and persistence" do
    test "processes, persists and retrieves a decoded event", %{monitor: pid} do
      {:ok, sub_id} = EventMonitor.subscribe(pid, @contract, "Transfer")
      log = transfer_log(selector(), "1234", "abcd", 1000)

      {:ok, event} = EventMonitor.process_event(pid, @contract, selector(), log)

      assert event.contract_address == @contract
      assert event.event_name == "Transfer"
      assert event.block_number == 1
      assert event.args == [1000]
      assert event.delivered_to == [sub_id]

      {:ok, count} = EventMonitor.event_count(pid)
      assert count == 1

      {:ok, events} = EventMonitor.events(pid)
      assert length(events) == 1
      assert hd(events).id == event.id

      {:ok, replayed} = EventMonitor.replay(pid)
      assert length(replayed) == 1
    end

    test "syncs multiple historical logs", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")
      logs = [transfer_log(selector(), "1111", "2222", 5, 10), transfer_log(selector(), "3333", "4444", 7, 20)]

      {:ok, processed} = EventMonitor.sync_historical(pid, @contract, selector(), logs)

      assert processed == 2
      {:ok, count} = EventMonitor.event_count(pid)
      assert count == 2

      {:ok, events} = EventMonitor.events(pid, from_block: 15)
      assert length(events) == 1
      assert hd(events).block_number == 20
    end

    test "filters events by contract, name and block range", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "a", "b", 1, 1))
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "c", "d", 2, 5))
      EventMonitor.process_event(pid, "0x9999999999999999999999999999999999999999", selector(), transfer_log(selector(), "e", "f", 3, 9))

      {:ok, events} = EventMonitor.events(pid, contract_address: @contract)
      assert length(events) == 2

      {:ok, events} = EventMonitor.events(pid, from_block: 2, to_block: 5)
      assert length(events) == 1
      assert hd(events).block_number == 5

      {:ok, events} = EventMonitor.events(pid, limit: 1)
      assert length(events) == 1
    end

    test "returns decode failure as a typed error", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")
      bad_log = Map.put(transfer_log(selector(), "a", "b", 1), "data", "0xZZZ")

      result = EventMonitor.process_event(pid, @contract, selector(), bad_log)

      assert match?({:error, %Error{code: :decode_failed}}, result)
    end
  end

  # --------------------------------------------------------------------------
  # Null inputs
  # --------------------------------------------------------------------------

  describe "null inputs" do
    test "rejects nil contract address", %{monitor: pid} do
      assert match?({:error, %Error{code: :invalid_argument, field: :contract_address, reason: :nil}},
                    EventMonitor.subscribe(pid, nil, "Transfer"))
    end

    test "rejects nil event name", %{monitor: pid} do
      assert match?({:error, %Error{code: :invalid_argument, field: :event_name, reason: :nil}},
                    EventMonitor.subscribe(pid, @contract, nil))
    end

    test "rejects nil contract address on process_event", %{monitor: pid} do
      assert match?({:error, %Error{field: :contract_address}},
                    EventMonitor.process_event(pid, nil, selector(), %{}))
    end
  end

  # --------------------------------------------------------------------------
  # Empty inputs
  # --------------------------------------------------------------------------

  describe "empty inputs" do
    test "rejects empty contract address", %{monitor: pid} do
      assert match?({:error, %Error{code: :invalid_argument, field: :contract_address, reason: :empty}},
                    EventMonitor.subscribe(pid, "", "Transfer"))
    end

    test "rejects empty event name", %{monitor: pid} do
      assert match?({:error, %Error{code: :invalid_argument, field: :event_name, reason: :empty}},
                    EventMonitor.subscribe(pid, @contract, ""))
    end
  end

  # --------------------------------------------------------------------------
  # Boundary
  # --------------------------------------------------------------------------

  describe "boundary values" do
    test "handles block 0 (lower bound)", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")
      log = transfer_log(selector(), "a", "b", 0, 0)

      {:ok, event} = EventMonitor.process_event(pid, @contract, selector(), log)
      assert event.block_number == 0

      {:ok, events} = EventMonitor.events(pid, from_block: 0)
      assert length(events) == 1
    end

    test "handles maximum integer block number (upper bound)", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")
      max_block = :math.pow(2, 53) |> trunc()
      log = transfer_log(selector(), "a", "b", 42, max_block)

      {:ok, event} = EventMonitor.process_event(pid, @contract, selector(), log)
      assert event.block_number == max_block

      {:ok, events} = EventMonitor.events(pid, from_block: max_block)
      assert length(events) == 1
      assert hd(events).block_number == max_block
    end

    test "from_block is inclusive at exact boundary", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "a", "b", 1, 5))
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "c", "d", 2, 10))

      {:ok, events} = EventMonitor.events(pid, from_block: 10)
      assert length(events) == 1
      assert hd(events).block_number == 10

      {:ok, events} = EventMonitor.events(pid, from_block: 11)
      assert events == []
    end

    test "to_block is inclusive at exact boundary", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "a", "b", 1, 5))
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "c", "d", 2, 10))

      {:ok, events} = EventMonitor.events(pid, to_block: 5)
      assert length(events) == 1
      assert hd(events).block_number == 5

      {:ok, events} = EventMonitor.events(pid, to_block: 4)
      assert events == []
    end

    test "limit of 0 returns no events", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "a", "b", 1, 1))

      {:ok, events} = EventMonitor.events(pid, limit: 0)
      assert events == []
    end

    test "limit larger than event count returns all events", %{monitor: pid} do
      EventMonitor.subscribe(pid, @contract, "Transfer")
      EventMonitor.process_event(pid, @contract, selector(), transfer_log(selector(), "a", "b", 1, 1))

      {:ok, events} = EventMonitor.events(pid, limit: 1_000_000)
      assert length(events) == 1
    end

    test "rejects malformed contract address", %{monitor: pid} do
      assert match?({:error, %Error{code: :invalid_argument, field: :contract_address, reason: :malformed}},
                    EventMonitor.subscribe(pid, "not_an_address", "Transfer"))
    end
  end

  # --------------------------------------------------------------------------
  # Negative / malformed
  # --------------------------------------------------------------------------

  describe "negative / malformed" do
    test "rejects non-binary contract address", %{monitor: pid} do
      assert match?({:error, %Error{code: :invalid_argument}},
                    EventMonitor.subscribe(pid, :not_an_address, "Transfer"))
    end

    test "rejects non-string event name", %{monitor: pid} do
      assert match?({:error, %Error{code: :invalid_argument, field: :event_name}},
                    EventMonitor.subscribe(pid, @contract, :not_a_name))
    end

    test "rejects non-list logs for sync_historical", %{monitor: pid} do
      assert match?({:error, %Error{code: :invalid_argument, field: :logs}},
                    EventMonitor.sync_historical(pid, @contract, selector(), "not_a_list"))
    end

    test "unsubscribe unknown id returns not_found", %{monitor: pid} do
      assert {:error, :not_found} = EventMonitor.unsubscribe(pid, "nope")
    end

    test "remove_webhook unknown url returns not_found", %{monitor: pid} do
      assert {:error, :not_found} = EventMonitor.remove_webhook(pid, "http://example.com/hook")
    end

    test "notify_webhook captures network failure without crashing", %{monitor: pid} do
      result = EventMonitor.notify_webhook("http://127.0.0.1:1/webhook", %EventMonitor.Event{event_name: "Transfer", received_at: DateTime.utc_now()})
      assert match?({:error, %Error{code: :webhook_failed}}, result)
    end
  end

  # --------------------------------------------------------------------------
  # Webhooks
  # --------------------------------------------------------------------------

  describe "webhooks" do
    test "adds, lists and removes webhooks", %{monitor: pid} do
      assert {:ok, "http://example.com/hook"} = EventMonitor.add_webhook(pid, "http://example.com/hook")
      assert {:ok, ["http://example.com/hook"]} = EventMonitor.webhooks(pid)
      assert {:ok, "http://example.com/hook"} = EventMonitor.remove_webhook(pid, "http://example.com/hook")
      assert {:ok, []} = EventMonitor.webhooks(pid)
    end

    test "rejects duplicate webhook", %{monitor: pid} do
      EventMonitor.add_webhook(pid, "http://example.com/hook")
      assert match?({:error, %Error{code: :invalid_argument, reason: :duplicate}},
                    EventMonitor.add_webhook(pid, "http://example.com/hook"))
    end
  end

  # --------------------------------------------------------------------------
  # Concurrency
  # --------------------------------------------------------------------------

  describe "concurrency" do
    test "concurrent subscriptions are atomic with no lost updates", %{monitor: pid} do
      contracts = for i <- 1..20, do: "0x#{String.duplicate(Integer.to_string(i), 39)}"

      results =
        contracts
        |> Enum.map(fn c ->
          Task.async(fn -> EventMonitor.subscribe(pid, c, "Event") end)
        end)
        |> Task.yield_many(5000)

      successes = for {_task, {:ok, {:ok, _id}}} <- results, do: :ok
      assert length(successes) == 20

      {:ok, subs} = EventMonitor.list_subscriptions(pid)
      assert length(subs) == 20
    end

    test "concurrent subscribe to same pair is idempotent (no double registration)", %{monitor: pid} do
      results =
        for _ <- 1..10 do
          Task.async(fn -> EventMonitor.subscribe(pid, @contract, "Shared") end)
        end
        |> Task.yield_many(5000)

      ids = for {_task, {:ok, {:ok, id}}} <- results, do: id
      assert length(ids) == 10
      assert Enum.all?(ids, &(&1 == hd(ids)))

      {:ok, subs} = EventMonitor.list_subscriptions(pid)
      assert length(subs) == 1
    end
  end

  # --------------------------------------------------------------------------
  # Regression (issue #75: Smart Contract Event Monitoring System)
  # --------------------------------------------------------------------------

  describe "regression" do
    test "event monitoring system resolves the reported defect end to end", %{monitor: pid} do
      {:ok, sub_id} = EventMonitor.subscribe(pid, @contract, "Transfer", from_block: 0)

      log = transfer_log(selector(), "deadbeef", "cafebab", 42, 7)
      {:ok, event} = EventMonitor.process_event(pid, @contract, selector(), log)

      assert event.event_name == "Transfer"
      assert event.delivered_to == [sub_id]

      {:ok, count} = EventMonitor.event_count(pid)
      assert count == 1

      {:ok, events} = EventMonitor.events(pid, event_name: "Transfer")
      assert length(events) == 1
      assert hd(events).args == [42]

      {:ok, replayed} = EventMonitor.replay(pid)
      assert length(replayed) == 1
      assert hd(replayed).id == event.id
    end
  end
end
