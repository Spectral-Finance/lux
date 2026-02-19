defmodule Lux.Prisms.EventMonitor.RegisterWebhookPrismTest do
  use UnitCase, async: false

  alias Lux.EventMonitor
  alias Lux.EventMonitor.Store
  alias Lux.EventMonitor.Webhook
  alias Lux.Prisms.EventMonitor.RegisterWebhookPrism

  setup do
    suffix = System.unique_integer([:positive])
    store_name = :"wh_prism_store_#{suffix}"
    webhook_name = :"wh_prism_webhook_#{suffix}"
    monitor_name = :"wh_prism_monitor_#{suffix}"

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
    test "registers a webhook", %{monitor: monitor} do
      {:ok, result} = RegisterWebhookPrism.handler(
        %{
          url: "https://example.com/hook",
          filter: %{event_name: "Transfer"},
          secret: "my_secret"
        },
        %{monitor: monitor}
      )

      assert result.status == "active"
      assert is_binary(result.webhook_id)
      assert result.url == "https://example.com/hook"
    end

    test "registers webhook with string keys", %{monitor: monitor} do
      {:ok, result} = RegisterWebhookPrism.handler(
        %{
          "url" => "https://example.com/hook",
          "filter" => %{"event_name" => "Transfer"},
          "headers" => %{"Authorization" => "Bearer token"}
        },
        %{monitor: monitor}
      )

      assert result.status == "active"
    end

    test "registers webhook with minimal config", %{monitor: monitor} do
      {:ok, result} = RegisterWebhookPrism.handler(
        %{url: "https://example.com"},
        %{monitor: monitor}
      )

      assert result.status == "active"
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = RegisterWebhookPrism.view()
      assert prism.input_schema.required == ["url"]
    end

    test "validates output schema" do
      prism = RegisterWebhookPrism.view()
      assert prism.output_schema.required == ["webhook_id", "status"]
    end
  end
end
