defmodule Lux.Signal.Router.LocalTest do
  use UnitCase, async: true

  alias Lux.Signal
  alias Lux.Signal.Router.Local

  require Logger

  # Single test agent module for all tests
  defmodule TestAgent1 do
    @moduledoc false
    use Lux.Agent,
      name: "Test Agent",
      description: "A test agent",
      goal: "Help with testing",
      capabilities: []
  end

  defmodule TestAgent2 do
    @moduledoc false
    use Lux.Agent,
      name: "Test Agent",
      description: "A test agent",
      goal: "Help with testing",
      capabilities: []
  end

  # Helper for eventually asserting conditions
  defp assert_eventually(expression, opts \\ []) do
    assert (opts[:every_ms] || 100)
           |> Stream.interval()
           |> Stream.take(opts[:attempts] || 10)
           |> Enum.any?(expression)
  end

  describe "starting router" do
    test "can start an unnamed router" do
      case Local.start_link() do
        {:ok, pid} ->
          assert is_pid(pid)

        {:error, {:already_started, pid}} ->
          assert is_pid(pid)
      end
    end

    test "can start a named router" do
      assert {:ok, pid} = Local.start_link(name: :test_router)
      assert Process.whereis(:test_router) == pid
    end

    test "can start multiple named routers" do
      assert {:ok, pid1} = Local.start_link(name: :router1)
      assert {:ok, pid2} = Local.start_link(name: :router2)
      assert pid1 != pid2
    end
  end

  describe "routing signals" do
    setup do
      # Generate unique names for this test
      unique_id = System.unique_integer([:positive])
      registry_name = :"agent_registry_#{unique_id}"
      hub_name = :"test_hub_#{unique_id}"
      router_name = :"test_router_#{unique_id}"

      # Start the registry
      start_supervised!({Registry, keys: :duplicate, name: registry_name})

      # Start router and hub
      start_supervised!({Lux.AgentHub, name: hub_name})
      start_supervised!({Local, name: router_name})

      # Start test agents with unique names
      {:ok, agent1_pid} = start_supervised({TestAgent1, name: :"agent1_#{unique_id}"})
      {:ok, agent2_pid} = start_supervised({TestAgent2, name: :"agent2_#{unique_id}"})

      # Get agent states
      agent1 = :sys.get_state(agent1_pid)
      agent2 = :sys.get_state(agent2_pid)

      # Register agents with capabilities
      :ok = Lux.AgentHub.register(hub_name, agent1, agent1_pid, [:test, :research])
      :ok = Lux.AgentHub.register(hub_name, agent2, agent2_pid, [:test, :writing])

      {:ok,
       %{
         registry: registry_name,
         router: router_name,
         hub: hub_name,
         agent1: agent1,
         agent2: agent2,
         agent1_pid: agent1_pid,
         agent2_pid: agent2_pid
       }}
    end

    test "can route signal to specific agent", %{
      router: router,
      hub: hub,
      agent1: agent1
    } do
      signal =
        Signal.new(%{
          id: "test_signal",
          payload: %{type: :text, data: "test message"},
          sender: "sender",
          recipient: agent1.id
        })

      # Subscribe to delivery events
      :ok = Local.subscribe(signal.id, name: router)
      assert :ok = Local.route(signal, name: router, hub: hub)

      # Wait for signal and delivery notification
      assert_eventually(fn _ ->
        receive do
          {:signal, ^signal} -> true
          _ -> false
        after
          0 -> false
        end
      end)

      assert_eventually(fn _ ->
        receive do
          {:signal_delivered, "test_signal"} -> true
          _ -> false
        after
          0 -> false
        end
      end)
    end

    test "handles failed deliveries", %{
      router: router,
      hub: hub,
      agent1: agent1,
      agent1_pid: agent1_pid
    } do
      signal =
        Signal.new(%{
          id: "test_signal",
          payload: %{type: :text, data: "test message"},
          sender: "sender",
          recipient: agent1.id
        })

      # Subscribe to delivery events
      :ok = Local.subscribe(signal.id, name: router)

      # Stop the agent to simulate failure
      Process.exit(agent1_pid, :kill)
      # Give time for the process to exit
      Process.sleep(100)

      assert :ok = Local.route(signal, name: router, hub: hub)

      # Wait for failure notification
      assert_eventually(fn _ ->
        receive do
          {:signal_failed, "test_signal", _reason} -> true
          _ -> false
        after
          0 -> false
        end
      end)
    end
  end

  describe "signal subscriptions" do
    setup do
      router_name = :"test_router_#{System.unique_integer([:positive])}"
      {:ok, _router} = start_supervised({Local, name: router_name})
      {:ok, router: router_name}
    end

    test "can subscribe and unsubscribe from signal events", %{router: router} do
      signal_id = "test_signal"

      # Subscribe
      assert :ok = Local.subscribe(signal_id, name: router)

      # Unsubscribe
      assert :ok = Local.unsubscribe(signal_id, name: router)

      # Send a signal event
      send(router, {:notify_subscribers, {:signal_delivered, signal_id}})

      # Should not receive any messages since we unsubscribed
      refute_receive {:signal_delivered, ^signal_id}, 100
    end

    test "multiple subscribers receive signal events", %{router: router} do
      signal_id = "test_signal"

      # Subscribe current process
      assert :ok = Local.subscribe(signal_id, name: router)

      # Send a signal event
      send(router, {:notify_subscribers, {:signal_delivered, signal_id}})

      # Should receive the message
      assert_receive {:signal_delivered, ^signal_id}, 100
    end
  end
end
