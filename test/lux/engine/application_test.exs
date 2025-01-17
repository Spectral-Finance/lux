defmodule Lux.Engine.ApplicationTest do
  use ExUnit.Case, async: false

  setup do
    # Stop the application if it's running
    Application.stop(:lux)

    # Start it fresh
    {:ok, _} = Application.ensure_all_started(:lux)

    on_exit(fn ->
      Application.stop(:lux)
    end)

    :ok
  end

  describe "application startup" do
    test "registry is started" do
      # Try to start the registry again - should fail because it's already started
      assert {:error, {:already_started, _pid}} =
               Registry.start_link(keys: :unique, name: Lux.Engine.Registry)
    end

    test "queue supervisor is started" do
      queue_sup = Process.whereis(Lux.Engine.QueueSupervisor)
      assert queue_sup != nil
      assert DynamicSupervisor.which_children(queue_sup) == []
    end

    test "router supervisor is started" do
      router_sup = Process.whereis(Lux.Engine.RouterSupervisor)
      assert router_sup != nil
      assert DynamicSupervisor.which_children(router_sup) == []
    end

    test "delivery supervisor is started" do
      delivery_sup = Process.whereis(Lux.Engine.DeliverySupervisor)
      assert delivery_sup != nil
      assert DynamicSupervisor.which_children(delivery_sup) == []
    end

    test "all supervisors use one_for_one strategy" do
      # Get supervisor specs
      queue_sup = Process.whereis(Lux.Engine.QueueSupervisor)
      router_sup = Process.whereis(Lux.Engine.RouterSupervisor)
      delivery_sup = Process.whereis(Lux.Engine.DeliverySupervisor)

      # Get supervisor status
      queue_status = :sys.get_status(queue_sup)
      router_status = :sys.get_status(router_sup)
      delivery_status = :sys.get_status(delivery_sup)

      # Extract state from status
      assert {:status, _, {:module, :gen_server},
              [_, :running, _, _, [header: _, data: _, data: data]]} = queue_status

      assert [{~c"State", %DynamicSupervisor{strategy: :one_for_one}} | _] = data

      assert {:status, _, {:module, :gen_server},
              [_, :running, _, _, [header: _, data: _, data: data]]} = router_status

      assert [{~c"State", %DynamicSupervisor{strategy: :one_for_one}} | _] = data

      assert {:status, _, {:module, :gen_server},
              [_, :running, _, _, [header: _, data: _, data: data]]} = delivery_status

      assert [{~c"State", %DynamicSupervisor{strategy: :one_for_one}} | _] = data
    end
  end
end
