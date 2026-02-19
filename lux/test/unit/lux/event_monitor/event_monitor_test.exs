defmodule Lux.EventMonitorTest do
  use UnitCase, async: false

  alias Lux.EventMonitor
  alias Lux.EventMonitor.EventLog
  alias Lux.EventMonitor.Store
  alias Lux.EventMonitor.Webhook

  defmodule MockLogFetcher do
    @moduledoc false

    def fetch_logs(_subscription, _from_block) do
      logs = [
        %{
          "address" => "0xdead",
          "topics" => [
            "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            "0x000000000000000000000000ab5801a7d398351b8be11c439e05c5b3259aec9b",
            "0x0000000000000000000000004838b106fce9647bdf1e7877bf73ce8b0bad5f97"
          ],
          "data" => "0x00000000000000000000000000000000000000000000000000000000000f4240",
          "blockNumber" => "18000100",
          "transactionHash" => "0x#{:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)}",
          "logIndex" => "0",
          "timeStamp" => "1700000000"
        },
        %{
          "address" => "0xdead",
          "topics" => [
            "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            "0x0000000000000000000000004838b106fce9647bdf1e7877bf73ce8b0bad5f97",
            "0x000000000000000000000000ab5801a7d398351b8be11c439e05c5b3259aec9b"
          ],
          "data" => "0x0000000000000000000000000000000000000000000000000000000000001000",
          "blockNumber" => "18000200",
          "transactionHash" => "0x#{:crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)}",
          "logIndex" => "1",
          "timeStamp" => "1700001200"
        }
      ]

      {:ok, logs, 18_000_200}
    end
  end

  defmodule EmptyLogFetcher do
    @moduledoc false

    def fetch_logs(_subscription, _from_block) do
      {:ok, [], 18_000_000}
    end
  end

  defmodule FailingLogFetcher do
    @moduledoc false

    def fetch_logs(_subscription, _from_block) do
      {:error, "RPC timeout"}
    end
  end

  setup do
    # Use unique names to avoid conflicts
    suffix = System.unique_integer([:positive])
    store_name = :"em_store_#{suffix}"
    webhook_name = :"em_webhook_#{suffix}"
    monitor_name = :"em_monitor_#{suffix}"

    {:ok, store_pid} = Store.start_link(name: store_name)
    {:ok, webhook_pid} = Webhook.start_link(name: webhook_name)

    {:ok, monitor_pid} =
      EventMonitor.start_link(
        name: monitor_name,
        store: store_name,
        webhook: webhook_name,
        log_fetcher: MockLogFetcher
      )

    on_exit(fn ->
      for pid <- [monitor_pid, webhook_pid, store_pid] do
        if Process.alive?(pid), do: GenServer.stop(pid)
      end
    end)

    %{monitor: monitor_name, store: store_name, webhook: webhook_name}
  end

  describe "subscribe/2" do
    test "creates a subscription", %{monitor: monitor} do
      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        event_names: ["Transfer"],
        from_block: 18_000_000,
        poll_interval_ms: 60_000
      })

      assert is_binary(sub_id)
      assert String.starts_with?(sub_id, "sub_")
    end

    test "subscription appears in list", %{monitor: monitor} do
      {:ok, _sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1
      })

      subs = EventMonitor.list_subscriptions(monitor)
      assert length(subs) == 1
      assert hd(subs).address == "0xdead"
    end

    test "creates subscription with ABI", %{monitor: monitor} do
      abi = [
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

      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        abi: abi
      })

      {:ok, sub} = EventMonitor.get_subscription(monitor, sub_id)
      assert sub.abi == abi
    end
  end

  describe "unsubscribe/2" do
    test "removes a subscription", %{monitor: monitor} do
      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        poll_interval_ms: 60_000
      })

      assert :ok = EventMonitor.unsubscribe(monitor, sub_id)
      assert EventMonitor.list_subscriptions(monitor) == []
    end

    test "returns error for non-existent subscription", %{monitor: monitor} do
      assert {:error, :not_found} = EventMonitor.unsubscribe(monitor, "nonexistent")
    end
  end

  describe "get_subscription/2" do
    test "returns subscription by ID", %{monitor: monitor} do
      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        poll_interval_ms: 60_000
      })

      {:ok, sub} = EventMonitor.get_subscription(monitor, sub_id)
      assert sub.address == "0xdead"
      assert sub.chain_id == 1
    end

    test "returns error for non-existent subscription", %{monitor: monitor} do
      assert {:error, :not_found} = EventMonitor.get_subscription(monitor, "nonexistent")
    end
  end

  describe "poll_now/2" do
    test "fetches and stores events", %{monitor: monitor, store: store} do
      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        from_block: 18_000_000,
        poll_interval_ms: 999_999
      })

      {:ok, events} = EventMonitor.poll_now(monitor, sub_id)

      assert length(events) == 2
      assert Enum.all?(events, &is_struct(&1, EventLog))

      # Events should be stored
      assert Store.count(store) == 2
    end

    test "decodes events when ABI is provided", %{monitor: monitor} do
      abi = [
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

      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        abi: abi,
        from_block: 18_000_000,
        poll_interval_ms: 999_999
      })

      {:ok, events} = EventMonitor.poll_now(monitor, sub_id)

      assert length(events) == 2
      assert Enum.all?(events, &(&1.event_name == "Transfer"))
      assert Enum.all?(events, &is_map(&1.decoded_params))
    end

    test "filters by event names", %{monitor: monitor} do
      abi = [
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

      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        abi: abi,
        event_names: ["NonExistent"],
        from_block: 18_000_000,
        poll_interval_ms: 999_999
      })

      {:ok, events} = EventMonitor.poll_now(monitor, sub_id)
      assert events == []
    end

    test "updates last synced block", %{monitor: monitor} do
      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        from_block: 18_000_000,
        poll_interval_ms: 999_999
      })

      EventMonitor.poll_now(monitor, sub_id)

      {:ok, sub} = EventMonitor.get_subscription(monitor, sub_id)
      assert sub.last_synced_block == 18_000_200
    end

    test "returns error for non-existent subscription", %{monitor: monitor} do
      assert {:error, :not_found} = EventMonitor.poll_now(monitor, "nonexistent")
    end
  end

  describe "on_event/2" do
    test "invokes callback on new events", %{monitor: monitor} do
      test_pid = self()

      EventMonitor.on_event(monitor, fn event ->
        send(test_pid, {:event_received, event})
      end)

      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        from_block: 18_000_000,
        poll_interval_ms: 999_999
      })

      EventMonitor.poll_now(monitor, sub_id)

      assert_receive {:event_received, %EventLog{address: "0xdead"}}, 1000
      assert_receive {:event_received, %EventLog{address: "0xdead"}}, 1000
    end
  end

  describe "register_webhook/2 and unregister_webhook/2" do
    test "registers and unregisters webhooks through monitor", %{monitor: monitor} do
      {:ok, wh_id} = EventMonitor.register_webhook(monitor, %{
        url: "https://example.com/hook",
        filter: %{event_name: "Transfer"}
      })

      assert is_binary(wh_id)

      assert :ok = EventMonitor.unregister_webhook(monitor, wh_id)
    end
  end

  describe "query_events/2" do
    test "queries stored events", %{monitor: monitor, store: store} do
      # Insert some events directly into store
      events = [
        %EventLog{
          address: "0xusdc",
          topics: ["0xtopic"],
          data: "0x",
          block_number: 100,
          transaction_hash: "0xabc",
          log_index: 0,
          chain_id: 1,
          event_name: "Transfer"
        },
        %EventLog{
          address: "0xusdc",
          topics: ["0xtopic"],
          data: "0x",
          block_number: 200,
          transaction_hash: "0xdef",
          log_index: 0,
          chain_id: 1,
          event_name: "Approval"
        }
      ]

      Store.insert_batch(store, events)

      {:ok, results} = EventMonitor.query_events(monitor, %{event_name: "Transfer"})
      assert length(results) == 1
      assert hd(results).event_name == "Transfer"
    end
  end

  describe "stats/1" do
    test "returns monitoring statistics", %{monitor: monitor} do
      {:ok, _sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        poll_interval_ms: 999_999
      })

      {:ok, _wh_id} = EventMonitor.register_webhook(monitor, %{
        url: "https://example.com"
      })

      stats = EventMonitor.stats(monitor)

      assert stats.subscription_count == 1
      assert stats.active_subscriptions == 1
      assert stats.webhook_count == 1
      assert stats.stored_events == 0
      assert stats.callback_count == 0
    end
  end

  describe "error handling" do
    test "handles fetch failures gracefully" do
      suffix = System.unique_integer([:positive])
      store_name = :"fail_store_#{suffix}"
      webhook_name = :"fail_webhook_#{suffix}"
      monitor_name = :"fail_monitor_#{suffix}"

      {:ok, store_pid} = Store.start_link(name: store_name)
      {:ok, webhook_pid} = Webhook.start_link(name: webhook_name)

      {:ok, monitor_pid} =
        EventMonitor.start_link(
          name: monitor_name,
          store: store_name,
          webhook: webhook_name,
          log_fetcher: FailingLogFetcher
        )

      {:ok, sub_id} = EventMonitor.subscribe(monitor_name, %{
        address: "0xdead",
        chain_id: 1,
        from_block: 18_000_000,
        poll_interval_ms: 999_999
      })

      {:ok, events} = EventMonitor.poll_now(monitor_name, sub_id)
      assert events == []

      for pid <- [monitor_pid, webhook_pid, store_pid] do
        if Process.alive?(pid), do: GenServer.stop(pid)
      end
    end
  end
end
