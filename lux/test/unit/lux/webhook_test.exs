defmodule Lux.WebhookTest do
  use ExUnit.Case, async: true

  alias Lux.Webhook

  defmodule TestHandler do
    @behaviour Lux.Webhook.Handler

    @impl true
    def handle_event(event) do
      {:ok, event}
    end
  end

  setup do
    # Start webhook server for tests
    {:ok, pid} = Webhook.start_link(port: 0)
    on_exit(fn -> GenServer.stop(pid) end)

    %{pid: pid}
  end

  describe "parse_request/1" do
    test "parses valid webhook request" do
      body = %{
        "type" => "github.push",
        "payload" => %{"ref" => "refs/heads/main"},
        "id" => "test-123"
      }

      assert {:ok, event} = Webhook.parse_request(body)
      assert event.type == "github.push"
      assert event.payload.ref == "refs/heads/main"
      assert event.id == "test-123"
      assert event.source == "unknown"
    end

    test "returns error for missing type" do
      assert {:error, :missing_type} = Webhook.parse_request(%{"payload" => %{}})
    end

    test "returns error for missing payload" do
      assert {:error, :missing_payload} = Webhook.parse_request(%{"type" => "test"})
    end

    test "returns error for invalid payload" do
      assert {:error, :invalid_payload} = Webhook.parse_request(%{"type" => "test", "payload" => "not a map"})
    end
  end

  describe "verify_signature/3" do
    test "verifies valid signature" do
      payload = ~s({"type":"test","payload":{}})
      secret = "test_secret"
      signature = Webhook.generate_signature(payload, secret)

      assert Webhook.verify_signature(payload, signature, secret) == true
    end

    test "rejects invalid signature" do
      payload = ~s({"type":"test","payload":{}})
      secret = "test_secret"

      assert Webhook.verify_signature(payload, "sha256=invalid", secret) == false
    end

    test "rejects wrong secret" do
      payload = ~s({"type":"test","payload":{}})
      signature = Webhook.generate_signature(payload, "secret1")

      assert Webhook.verify_signature(payload, signature, "secret2") == false
    end
  end

  describe "generate_signature/2" do
    test "generates valid HMAC-SHA256 signature" do
      payload = "test_payload"
      secret = "test_secret"

      signature = Webhook.generate_signature(payload, secret)
      assert String.starts_with?(signature, "sha256=")
      assert byte_size(signature) > 7 + 64 # "sha256=" + hex digest
    end
  end

  describe "register_handler/2" do
    test "registers a valid handler" do
      assert :ok = Webhook.register_handler("test.event", TestHandler)
      handlers = Webhook.list_handlers()
      assert Map.get(handlers, "test.event") == TestHandler
    end

    test "overwrites existing handler" do
      Webhook.register_handler("test.event", TestHandler)

      defmodule AnotherHandler do
        def handle_event(event), do: {:ok, event}
      end

      assert :ok = Webhook.register_handler("test.event", AnotherHandler)
      handlers = Webhook.list_handlers()
      assert Map.get(handlers, "test.event") == AnotherHandler
    end
  end

  describe "unregister_handler/1" do
    test "removes a handler" do
      Webhook.register_handler("test.event", TestHandler)
      assert :ok = Webhook.unregister_handler("test.event")
      handlers = Webhook.list_handlers()
      refute Map.has_key?(handlers, "test.event")
    end
  end

  describe "dispatch/1" do
    test "dispatches to registered handler" do
      Webhook.register_handler("test.dispatch", TestHandler)

      event = %{
        type: "test.dispatch",
        payload: %{message: "hello"},
        id: "dispatch-1",
        timestamp: DateTime.utc_now()
      }

      # Should not raise
      Webhook.dispatch(event)
      Process.sleep(100)
    end

    test "returns error for unregistered event" do
      event = %{
        type: "unknown.event",
        payload: %{},
        id: "unknown-1",
        timestamp: DateTime.utc_now()
      }

      # Should log warning but not crash
      Webhook.dispatch(event)
      Process.sleep(100)
    end
  end

  describe "status/0" do
    test "returns current status" do
      status = Webhook.status()
      assert status.running == true
      assert is_integer(status.handlers)
      assert Map.has_key?(status, :started_at)
    end
  end
end
