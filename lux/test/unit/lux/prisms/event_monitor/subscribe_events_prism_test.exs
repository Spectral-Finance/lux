defmodule Lux.Prisms.EventMonitor.SubscribeEventsPrismTest do
  use UnitCase, async: false

  alias Lux.EventMonitor
  alias Lux.EventMonitor.Store
  alias Lux.EventMonitor.Webhook
  alias Lux.Prisms.EventMonitor.SubscribeEventsPrism

  setup do
    suffix = System.unique_integer([:positive])
    store_name = :"sub_prism_store_#{suffix}"
    webhook_name = :"sub_prism_webhook_#{suffix}"
    monitor_name = :"sub_prism_monitor_#{suffix}"

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
    test "creates a subscription", %{monitor: monitor} do
      {:ok, result} = SubscribeEventsPrism.handler(
        %{
          address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
          chain_id: 1,
          event_names: ["Transfer"],
          from_block: 18_000_000,
          poll_interval_ms: 60_000
        },
        %{monitor: monitor}
      )

      assert result.status == "active"
      assert is_binary(result.subscription_id)
      assert result.address == "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
      assert result.chain_id == 1
    end

    test "creates subscription with string keys", %{monitor: monitor} do
      {:ok, result} = SubscribeEventsPrism.handler(
        %{
          "address" => "0xdead",
          "chain_id" => 137,
          "event_names" => ["Transfer"]
        },
        %{monitor: monitor}
      )

      assert result.status == "active"
      assert result.chain_id == 137
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SubscribeEventsPrism.view()

      assert prism.input_schema.required == ["address", "chain_id"]
      assert Map.has_key?(prism.input_schema.properties, :address)
      assert Map.has_key?(prism.input_schema.properties, :chain_id)
    end

    test "validates output schema" do
      prism = SubscribeEventsPrism.view()

      assert prism.output_schema.required == ["subscription_id", "status"]
    end
  end
end
