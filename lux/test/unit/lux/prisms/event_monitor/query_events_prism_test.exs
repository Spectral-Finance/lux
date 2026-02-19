defmodule Lux.Prisms.EventMonitor.QueryEventsPrismTest do
  use UnitCase, async: false

  alias Lux.EventMonitor
  alias Lux.EventMonitor.EventLog
  alias Lux.EventMonitor.Store
  alias Lux.EventMonitor.Webhook
  alias Lux.Prisms.EventMonitor.QueryEventsPrism

  setup do
    suffix = System.unique_integer([:positive])
    store_name = :"query_prism_store_#{suffix}"
    webhook_name = :"query_prism_webhook_#{suffix}"
    monitor_name = :"query_prism_monitor_#{suffix}"

    {:ok, store_pid} = Store.start_link(name: store_name)
    {:ok, webhook_pid} = Webhook.start_link(name: webhook_name)

    {:ok, monitor_pid} =
      EventMonitor.start_link(
        name: monitor_name,
        store: store_name,
        webhook: webhook_name
      )

    # Insert test events
    events = [
      %EventLog{
        address: "0xusdc",
        topics: ["0xtopic"],
        data: "0x",
        block_number: 100,
        transaction_hash: "0xabc",
        log_index: 0,
        chain_id: 1,
        event_name: "Transfer",
        decoded_params: %{"value" => 1000}
      },
      %EventLog{
        address: "0xusdc",
        topics: ["0xtopic"],
        data: "0x",
        block_number: 200,
        transaction_hash: "0xdef",
        log_index: 0,
        chain_id: 1,
        event_name: "Approval",
        decoded_params: %{"value" => 999}
      },
      %EventLog{
        address: "0xweth",
        topics: ["0xtopic"],
        data: "0x",
        block_number: 300,
        transaction_hash: "0xghi",
        log_index: 0,
        chain_id: 1,
        event_name: "Transfer",
        decoded_params: %{"value" => 500}
      }
    ]

    Store.insert_batch(store_name, events)

    on_exit(fn ->
      for pid <- [monitor_pid, webhook_pid, store_pid] do
        if Process.alive?(pid), do: GenServer.stop(pid)
      end
    end)

    %{monitor: monitor_name}
  end

  describe "handler/2" do
    test "queries all events", %{monitor: monitor} do
      {:ok, result} = QueryEventsPrism.handler(%{}, %{monitor: monitor})

      assert result.count == 3
      assert length(result.events) == 3
    end

    test "filters by event name", %{monitor: monitor} do
      {:ok, result} = QueryEventsPrism.handler(
        %{event_name: "Transfer"},
        %{monitor: monitor}
      )

      assert result.count == 2
      assert Enum.all?(result.events, &(&1.event_name == "Transfer"))
    end

    test "filters by address", %{monitor: monitor} do
      {:ok, result} = QueryEventsPrism.handler(
        %{address: "0xusdc"},
        %{monitor: monitor}
      )

      assert result.count == 2
    end

    test "supports limit", %{monitor: monitor} do
      {:ok, result} = QueryEventsPrism.handler(
        %{limit: 1},
        %{monitor: monitor}
      )

      assert result.count == 1
    end

    test "serializes events correctly", %{monitor: monitor} do
      {:ok, result} = QueryEventsPrism.handler(%{limit: 1}, %{monitor: monitor})

      event = hd(result.events)
      assert Map.has_key?(event, :address)
      assert Map.has_key?(event, :event_name)
      assert Map.has_key?(event, :block_number)
      assert Map.has_key?(event, :transaction_hash)
      assert Map.has_key?(event, :chain_id)
      assert Map.has_key?(event, :decoded_params)
    end
  end
end
