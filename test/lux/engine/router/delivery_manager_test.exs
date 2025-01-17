defmodule Lux.Engine.Router.DeliveryManagerTest do
  use ExUnit.Case, async: true
  require Logger

  alias Lux.Engine.Router.DeliveryManager

  # Mock delivery handler that simulates a specter's signal handler
  defmodule TestDeliveryHandler do
    def deliver_signal(signal, specter_id) do
      send(Process.whereis(:test_process), {:signal_handled, signal, specter_id})
      :ok
    end
  end

  # Mock handler that always returns error
  defmodule ErrorDeliveryHandler do
    def deliver_signal(signal, specter_id) do
      send(Process.whereis(:test_process), {:signal_error, signal, specter_id})
      {:error, :test_error}
    end
  end

  setup do
    # Register test process to receive messages
    test_pid = self()
    Process.register(test_pid, :test_process)

    on_exit(fn ->
      if Process.whereis(:test_process) == test_pid do
        Process.unregister(:test_process)
      end
    end)

    # Create unique name for this test's delivery manager
    name = :"delivery_manager_#{System.unique_integer([:positive])}"

    # Return test context
    %{name: name}
  end

  describe "start_link/1" do
    test "starts with valid options", %{name: name} do
      assert {:ok, pid} =
               DeliveryManager.start_link(name: name, delivery_handler: TestDeliveryHandler)

      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "requires name option" do
      assert_raise KeyError,
                   "key :name not found in: [delivery_handler: Lux.Engine.Router.DeliveryManagerTest.TestDeliveryHandler]",
                   fn ->
                     DeliveryManager.start_link(delivery_handler: TestDeliveryHandler)
                   end
    end

    test "requires delivery_handler option", %{name: name} do
      assert_raise KeyError, "key :delivery_handler not found in: [name: #{inspect(name)}]", fn ->
        DeliveryManager.start_link(name: name)
      end
    end
  end

  describe "deliver/3" do
    setup %{name: name} do
      {:ok, _pid} = DeliveryManager.start_link(name: name, delivery_handler: TestDeliveryHandler)
      :ok
    end

    test "successfully delivers signal to specter", %{name: name} do
      signal = %{type: "test.event", data: "test"}
      specter_id = "test_specter"

      DeliveryManager.deliver(name, signal, specter_id)

      assert_receive {:signal_handled, ^signal, ^specter_id}
    end

    test "logs warning on delivery error", %{name: name} do
      signal = %{type: "test.event", data: "test"}
      specter_id = "test_specter"
      error_name = :"#{name}_error"

      # Start manager with handler that returns error
      {:ok, _pid} =
        DeliveryManager.start_link(
          name: error_name,
          delivery_handler: ErrorDeliveryHandler
        )

      DeliveryManager.deliver(error_name, signal, specter_id)

      assert_receive {:signal_error, ^signal, ^specter_id}
    end
  end
end
