defmodule Lux.Integrations.Telegram.PollerTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Telegram.Poller
  import Mock

  defmodule DummyHandler do
    def handle_update(%{"update_id" => id}) do
      send(self(), {:update_received, id})
    end
  end

  test "polls and dispatches updates" do
    # We must mock Client.request to return some dummy updates
    # And we'll start the poller, let it run one poll, and stop it.

    with_mock Lux.Integrations.Telegram.Client, [:passthrough], [
      request: fn :post, "/getUpdates", _opts ->
        {:ok, %{"ok" => true, "result" => [%{"update_id" => 123}, %{"update_id" => 124}]}}
      end
    ] do
      
      # We test it by calling perform_poll directly since it's a private function,
      # or by starting the GenServer and capturing the messages it sends.
      # Because the DummyHandler uses send(self()), we can't easily capture it if the GenServer runs in another process unless we pass the PID.
      # Let's dynamically create a handler that sends to our test pid.
      test_pid = self()
      
      handler_module = Module.concat([DummyHandler, :Test, :Poller1])
      
      defmodule handler_module do
        def handle_update(%{"update_id" => id}) do
          send(unquote(test_pid), {:update_received, id})
        end
      end

      {:ok, pid} = Poller.start_link(name: nil, handler: handler_module, timeout: 0)

      assert_receive {:update_received, 123}, 1000
      assert_receive {:update_received, 124}, 1000

      GenServer.call(pid, :stop)
    end
  end
end
