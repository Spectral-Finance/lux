defmodule Lux.Prisms.EventMonitor.UnsubscribeEventsPrismTest do
  use UnitCase, async: false

  alias Lux.EventMonitor
  alias Lux.EventMonitor.Store
  alias Lux.EventMonitor.Webhook
  alias Lux.Prisms.EventMonitor.UnsubscribeEventsPrism

  setup do
    suffix = System.unique_integer([:positive])
    store_name = :"unsub_prism_store_#{suffix}"
    webhook_name = :"unsub_prism_webhook_#{suffix}"
    monitor_name = :"unsub_prism_monitor_#{suffix}"

    {:ok, store_pid} = Store.start_link(name: store_name)
    {:ok, webhook_pid} = Webhook.start_link(name: webhook_name)

    {:ok, monitor_pid} =
      EventMonitor.start_link(
        name: monitor_name,
        store: store_name,
        webhook: webhook_name
      )

    on_exit(fn ->
      for pid <- [monitor_pid, webhook_pid, store_pid] do
        if Process.alive?(pid), do: GenServer.stop(pid)
      end
    end)

    %{monitor: monitor_name}
  end

  describe "handler/2" do
    test "removes an existing subscription", %{monitor: monitor} do
      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        poll_interval_ms: 60_000
      })

      {:ok, result} = UnsubscribeEventsPrism.handler(
        %{subscription_id: sub_id},
        %{monitor: monitor}
      )

      assert result.subscription_id == sub_id
      assert result.status == "removed"
    end

    test "returns error for non-existent subscription", %{monitor: monitor} do
      {:error, message} = UnsubscribeEventsPrism.handler(
        %{subscription_id: "nonexistent"},
        %{monitor: monitor}
      )

      assert String.contains?(message, "not found")
    end

    test "works with string keys", %{monitor: monitor} do
      {:ok, sub_id} = EventMonitor.subscribe(monitor, %{
        address: "0xdead",
        chain_id: 1,
        poll_interval_ms: 60_000
      })

      {:ok, result} = UnsubscribeEventsPrism.handler(
        %{"subscription_id" => sub_id},
        %{monitor: monitor}
      )

      assert result.status == "removed"
    end
  end
end
