defmodule Lux.AgentHubTest do
  use UnitCase, async: true

  alias Lux.Agent
  alias Lux.AgentHub

  # Test agent module
  defmodule TestAgent do
    @moduledoc false
    use Lux.Agent

    def new(opts \\ %{}) do
      Agent.new(%{
        name: opts[:name] || "Test Agent",
        description: "A test agent",
        goal: "Help with testing",
        capabilities: opts[:capabilities] || []
      })
    end
  end

  describe "starting hubs" do
    test "can start an unnamed hub" do
      assert {:ok, pid} = AgentHub.start_link()
      assert is_pid(pid)
    end

    test "can start a named hub" do
      assert {:ok, pid} = AgentHub.start_link(name: :test_hub)
      assert is_pid(pid)
      assert Process.whereis(:test_hub) == pid
    end

    test "can start multiple named hubs" do
      assert {:ok, pid1} = AgentHub.start_link(name: :hub1)
      assert {:ok, pid2} = AgentHub.start_link(name: :hub2)
      assert pid1 != pid2
    end

    test "can be started under a supervisor" do
      child_spec = %{
        id: {AgentHub, :test_hub},
        start: {AgentHub, :start_link, [[name: :test_hub]]},
        type: :worker,
        restart: :permanent,
        shutdown: 5000
      }

      assert AgentHub.child_spec(name: :test_hub) == child_spec
    end
  end

  describe "agent registration and discovery" do
    setup do
      {:ok, _hub} = start_supervised({AgentHub, name: :test_hub})
      {:ok, agent_pid} = TestAgent.start_link()
      agent = :sys.get_state(agent_pid)

      {:ok, hub: :test_hub, agent: agent, agent_pid: agent_pid}
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
      {:ok, _hub} = start_supervised({AgentHub, name: :test_hub})
      {:ok, agent_pid} = TestAgent.start_link()
      agent = :sys.get_state(agent_pid)
      :ok = AgentHub.register(:test_hub, agent, agent_pid, [:test])

      {:ok, hub: :test_hub, agent: agent, agent_pid: agent_pid}
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
      {:ok, _} = start_supervised({AgentHub, name: :hub1})
      {:ok, _} = start_supervised({AgentHub, name: :hub2})
      {:ok, agent_pid} = TestAgent.start_link()
      agent = :sys.get_state(agent_pid)

      {:ok, hub1: :hub1, hub2: :hub2, agent: agent, agent_pid: agent_pid}
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
