defmodule Lux.AgentHubTest do
  use UnitCase, async: true

  alias Lux.Agent
  alias Lux.AgentHub

  # Test agent module
  defmodule TestAgent do
    @moduledoc false
    use Lux.Agent,
      name: "Test Agent",
      description: "A test agent",
      goal: "Help with testing",
      capabilities: []
  end

  # Helper function to start a TestAgent with a unique name
  defp start_unique_agent do
    # Generate a unique name for the agent
    agent_name = :"test_agent_#{:erlang.unique_integer([:positive])}"
    {:ok, agent_pid} = TestAgent.start_link(name: agent_name)
    agent = :sys.get_state(agent_pid)
    {agent, agent_pid}
  end

  describe "starting hubs" do
    test "default hub already started" do
      assert {:error, {:already_started, pid}} = AgentHub.start_link()
      assert is_pid(pid)
    end

    test "can start a named hub" do
      # Generate a unique hub name for this test
      hub_name = :"test_hub_#{:erlang.unique_integer([:positive])}"
      assert {:ok, pid} = AgentHub.start_link(name: hub_name)
      assert is_pid(pid)
      assert Process.whereis(hub_name) == pid
    end

    test "can start multiple named hubs" do
      # Generate unique hub names for this test
      hub1_name = :"hub1_#{:erlang.unique_integer([:positive])}"
      hub2_name = :"hub2_#{:erlang.unique_integer([:positive])}"

      assert {:ok, pid1} = AgentHub.start_link(name: hub1_name)
      assert {:ok, pid2} = AgentHub.start_link(name: hub2_name)
      assert pid1 != pid2
    end

    test "can be started under a supervisor" do
      # Generate a unique hub name for this test
      hub_name = :"test_hub_#{:erlang.unique_integer([:positive])}"

      child_spec = %{
        id: {AgentHub, hub_name},
        start: {AgentHub, :start_link, [[name: hub_name]]},
        type: :worker,
        restart: :permanent,
        shutdown: 5000
      }

      assert AgentHub.child_spec(name: hub_name) == child_spec
    end
  end

  describe "agent registration and discovery" do
    setup do
      # Generate a unique hub name for this test run
      hub_name = :"test_hub_#{:erlang.unique_integer([:positive])}"
      {:ok, _hub} = start_supervised({AgentHub, name: hub_name})

      # Start a unique agent
      {agent, agent_pid} = start_unique_agent()

      {:ok, hub: hub_name, agent: agent, agent_pid: agent_pid}
    end

    test "can register an agent", %{hub: hub, agent: agent, agent_pid: pid} do
      assert :ok = AgentHub.register(hub, agent, pid, [:test])
      assert [info] = AgentHub.list_agents(hub)
      assert info.agent.id == agent.id
      assert info.pid == pid
      assert info.capabilities == [:test]
      assert info.status == :available
    end

    test "can find agents by capability", %{hub: hub, agent: agent, agent_pid: pid} do
      :ok = AgentHub.register(hub, agent, pid, [:research])
      assert [info] = AgentHub.find_by_capability(hub, :research)
      assert info.agent.id == agent.id
      assert [] = AgentHub.find_by_capability(hub, :unknown)
    end

    test "can get agent info", %{hub: hub, agent: agent, agent_pid: pid} do
      :ok = AgentHub.register(hub, agent, pid, [:test])
      assert {:ok, info} = AgentHub.get_agent_info(hub, agent.id)
      assert info.agent.id == agent.id
      assert {:error, :not_found} = AgentHub.get_agent_info(hub, "unknown")
    end
  end

  describe "agent status management" do
    setup do
      # This is already using a unique hub name, but let's make the naming consistent
      hub_name = :"hub_#{:erlang.unique_integer([:positive])}"
      {:ok, _hub} = start_supervised({AgentHub, name: hub_name})

      # Start a unique agent
      {agent, agent_pid} = start_unique_agent()
      :ok = AgentHub.register(hub_name, agent, agent_pid, [:test])

      {:ok, hub: hub_name, agent: agent, agent_pid: agent_pid}
    end

    test "can update agent status", %{hub: hub, agent: agent} do
      assert :ok = AgentHub.update_status(hub, agent.id, :busy)
      assert {:ok, info} = AgentHub.get_agent_info(hub, agent.id)
      assert info.status == :busy
    end

    test "marks agent as offline when process dies", %{hub: hub, agent: agent, agent_pid: pid} do
      GenServer.stop(pid)
      # Give the hub time to process the DOWN message
      Process.sleep(100)
      assert {:ok, info} = AgentHub.get_agent_info(hub, agent.id)
      assert info.status == :offline
    end

    test "handles status updates for unknown agents", %{hub: hub} do
      assert {:error, :not_found} = AgentHub.update_status(hub, "unknown", :busy)
    end
  end

  describe "multiple hubs" do
    setup do
      # Generate unique hub names for this test run to avoid conflicts in parallel tests
      hub1_name = :"hub1_#{:erlang.unique_integer([:positive])}"
      hub2_name = :"hub2_#{:erlang.unique_integer([:positive])}"

      {:ok, _} = start_supervised({AgentHub, name: hub1_name})
      {:ok, _} = start_supervised({AgentHub, name: hub2_name})

      # Start a unique agent
      {agent, agent_pid} = start_unique_agent()

      {:ok, hub1: hub1_name, hub2: hub2_name, agent: agent, agent_pid: agent_pid}
    end

    test "hubs maintain separate agent registries", %{
      hub1: hub1,
      hub2: hub2,
      agent: agent,
      agent_pid: pid
    } do
      # Register in hub1
      :ok = AgentHub.register(hub1, agent, pid, [:test])
      assert [_] = AgentHub.list_agents(hub1)
      assert [] = AgentHub.list_agents(hub2)

      # Register in hub2 with different capabilities
      :ok = AgentHub.register(hub2, agent, pid, [:other])
      assert [info1] = AgentHub.list_agents(hub1)
      assert [info2] = AgentHub.list_agents(hub2)
      assert info1.capabilities == [:test]
      assert info2.capabilities == [:other]
    end

    test "status updates are hub-specific", %{
      hub1: hub1,
      hub2: hub2,
      agent: agent,
      agent_pid: pid
    } do
      :ok = AgentHub.register(hub1, agent, pid, [:test])
      :ok = AgentHub.register(hub2, agent, pid, [:test])

      # Update status in hub1
      :ok = AgentHub.update_status(hub1, agent.id, :busy)
      {:ok, info1} = AgentHub.get_agent_info(hub1, agent.id)
      {:ok, info2} = AgentHub.get_agent_info(hub2, agent.id)
      assert info1.status == :busy
      assert info2.status == :available
    end

    test "agent death affects all hubs", %{
      hub1: hub1,
      hub2: hub2,
      agent: agent,
      agent_pid: pid
    } do
      :ok = AgentHub.register(hub1, agent, pid, [:test])
      :ok = AgentHub.register(hub2, agent, pid, [:test])

      GenServer.stop(pid)
      # Give the hubs time to process the DOWN message
      Process.sleep(100)

      {:ok, info1} = AgentHub.get_agent_info(hub1, agent.id)
      {:ok, info2} = AgentHub.get_agent_info(hub2, agent.id)
      assert info1.status == :offline
      assert info2.status == :offline
    end
  end
end
