defmodule Lux.EventMonitor.WebhookTest do
  use UnitCase, async: false

  alias Lux.EventMonitor.EventLog
  alias Lux.EventMonitor.Webhook

  defmodule MockHTTPClient do
    @moduledoc false
    def post(url, payload, headers) do
      # Send to the test process stored in process dictionary or application env
      case Application.get_env(:lux, :webhook_test_pid) do
        nil -> :ok
        pid -> send(pid, {:webhook_sent, url, payload, headers})
      end

      {:ok, 200}
    end
  end

  defmodule FailingHTTPClient do
    @moduledoc false
    def post(_url, _payload, _headers) do
      {:error, "connection refused"}
    end
  end

  setup do
    name = :"webhook_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = Webhook.start_link(name: name, http_client: MockHTTPClient)
    Application.put_env(:lux, :webhook_test_pid, self())
    on_exit(fn ->
      Application.delete_env(:lux, :webhook_test_pid)
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)
    %{webhook: name}
  end

  defp make_event(attrs \\ %{}) do
    %EventLog{
      address: Map.get(attrs, :address, "0xdead"),
      topics: ["0xtopic0"],
      data: "0x",
      block_number: Map.get(attrs, :block_number, 100),
      transaction_hash: "0xabc",
      log_index: 0,
      chain_id: Map.get(attrs, :chain_id, 1),
      event_name: Map.get(attrs, :event_name, "Transfer"),
      decoded_params: %{"value" => 1000}
    }
  end

  describe "register/2 and list/1" do
    test "registers a webhook", %{webhook: webhook} do
      {:ok, id} = Webhook.register(webhook, %{url: "https://example.com/hook"})
      assert is_binary(id)

      webhooks = Webhook.list(webhook)
      assert length(webhooks) == 1
      assert hd(webhooks).url == "https://example.com/hook"
    end

    test "registers webhook with custom ID", %{webhook: webhook} do
      {:ok, id} = Webhook.register(webhook, %{id: "my_hook", url: "https://example.com"})
      assert id == "my_hook"
    end

    test "registers webhook with filter", %{webhook: webhook} do
      {:ok, _id} = Webhook.register(webhook, %{
        url: "https://example.com",
        filter: %{event_name: "Transfer"}
      })

      [wh] = Webhook.list(webhook)
      assert wh.filter == %{event_name: "Transfer"}
    end

    test "registers webhook with all options", %{webhook: webhook} do
      {:ok, _id} = Webhook.register(webhook, %{
        url: "https://example.com",
        filter: %{event_name: "Transfer"},
        headers: %{"Authorization" => "Bearer token"},
        secret: "my_secret",
        max_retries: 5,
        retry_delay_ms: 2000,
        active: true
      })

      [wh] = Webhook.list(webhook)
      assert wh.max_retries == 5
      assert wh.retry_delay_ms == 2000
      assert wh.secret == "my_secret"
      assert wh.headers == %{"Authorization" => "Bearer token"}
    end
  end

  describe "unregister/2" do
    test "removes a registered webhook", %{webhook: webhook} do
      {:ok, id} = Webhook.register(webhook, %{url: "https://example.com"})
      assert :ok = Webhook.unregister(webhook, id)
      assert Webhook.list(webhook) == []
    end

    test "returns error for non-existent webhook", %{webhook: webhook} do
      assert {:error, :not_found} = Webhook.unregister(webhook, "nonexistent")
    end
  end

  describe "set_active/3" do
    test "deactivates a webhook", %{webhook: webhook} do
      {:ok, id} = Webhook.register(webhook, %{url: "https://example.com"})
      assert :ok = Webhook.set_active(webhook, id, false)

      [wh] = Webhook.list(webhook)
      assert wh.active == false
    end

    test "reactivates a webhook", %{webhook: webhook} do
      {:ok, id} = Webhook.register(webhook, %{url: "https://example.com", active: false})
      assert :ok = Webhook.set_active(webhook, id, true)

      [wh] = Webhook.list(webhook)
      assert wh.active == true
    end

    test "returns error for non-existent webhook", %{webhook: webhook} do
      assert {:error, :not_found} = Webhook.set_active(webhook, "nonexistent", true)
    end
  end

  describe "notify/2" do
    test "sends notification to matching webhook", %{webhook: webhook} do
      {:ok, _id} = Webhook.register(webhook, %{
        url: "https://example.com/hook",
        filter: %{event_name: "Transfer"}
      })

      event = make_event(%{event_name: "Transfer"})
      :ok = Webhook.notify(webhook, event)

      # Give the async task time to execute
      Process.sleep(50)

      assert_received {:webhook_sent, "https://example.com/hook", payload, _headers}
      assert payload.event_name == "Transfer"
    end

    test "does not send to non-matching webhook", %{webhook: webhook} do
      {:ok, _id} = Webhook.register(webhook, %{
        url: "https://example.com/hook",
        filter: %{event_name: "Approval"}
      })

      event = make_event(%{event_name: "Transfer"})
      :ok = Webhook.notify(webhook, event)

      Process.sleep(50)

      refute_received {:webhook_sent, _, _, _}
    end

    test "does not send to inactive webhook", %{webhook: webhook} do
      {:ok, id} = Webhook.register(webhook, %{
        url: "https://example.com/hook",
        filter: %{}
      })

      Webhook.set_active(webhook, id, false)

      event = make_event()
      :ok = Webhook.notify(webhook, event)

      Process.sleep(50)

      refute_received {:webhook_sent, _, _, _}
    end
  end

  describe "notify_batch/2" do
    test "sends notifications for all matching events", %{webhook: webhook} do
      {:ok, _id} = Webhook.register(webhook, %{
        url: "https://example.com/hook",
        filter: %{event_name: "Transfer"}
      })

      events = [
        make_event(%{event_name: "Transfer"}),
        make_event(%{event_name: "Approval"}),
        make_event(%{event_name: "Transfer"})
      ]

      :ok = Webhook.notify_batch(webhook, events)

      Process.sleep(100)

      messages = flush_mailbox()
      webhook_messages = Enum.filter(messages, fn
        {:webhook_sent, _, _, _} -> true
        _ -> false
      end)

      assert length(webhook_messages) == 2
    end
  end

  defp flush_mailbox(acc \\ []) do
    receive do
      msg -> flush_mailbox([msg | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
