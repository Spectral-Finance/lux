defmodule LuxApp.Contexts.AgentsTest do
  use LuxApp.DataCase

  alias LuxApp.Contexts.Agents
  alias LuxApp.Schemas.Agent

  describe "agents" do
    @valid_attrs %{
      name: "Test Agent",
      description: "A test agent",
      goal: "Testing",
      template: "default",
      template_opts: %{},
      module: "TestModule",
      position_x: 100,
      position_y: 200,
      scheduled_actions: %{},
      signal_handlers: %{}
    }
    @update_attrs %{
      name: "Updated Agent",
      description: "An updated test agent",
      goal: "Updated Testing",
      position_x: 150,
      position_y: 250
    }
    @invalid_attrs %{name: nil}

    def agent_fixture(attrs \\ %{}) do
      {:ok, agent} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Agents.create_agent()

      agent
    end

    test "list_agents/1 returns all agents with pagination" do
      agent = agent_fixture()
      {:ok, {agents, _meta}} = Agents.list_agents(%{})
      assert Enum.map(agents, & &1.id) == [agent.id]
    end

    test "list_agents/1 with filtering" do
      agent1 = agent_fixture(%{name: "Agent One"})
      agent2 = agent_fixture(%{name: "Agent Two"})

      # Filter by name
      {:ok, {agents, _meta}} =
        Agents.list_agents(%{
          filters: [%{field: :name, op: :ilike_and, value: "One"}]
        })

      assert length(agents) == 1
      assert hd(agents).id == agent1.id

      # Filter by description
      {:ok, {agents, _meta}} =
        Agents.list_agents(%{
          filters: [%{field: :description, value: "A test agent"}]
        })

      assert length(agents) == 2
      assert Enum.map(agents, & &1.id) |> Enum.sort() == [agent1.id, agent2.id] |> Enum.sort()
    end

    test "get_agent!/1 returns the agent with given id" do
      agent = agent_fixture()
      assert Agents.get_agent!(agent.id) == agent
    end

    test "get_agent/1 returns the agent with given id" do
      agent = agent_fixture()
      assert Agents.get_agent(agent.id) == agent
    end

    test "get_agent/1 returns nil for non-existent id" do
      assert Agents.get_agent(Ecto.UUID.generate()) == nil
    end

    test "create_agent/1 with valid data creates a agent" do
      assert {:ok, %Agent{} = agent} = Agents.create_agent(@valid_attrs)
      assert agent.name == "Test Agent"
      assert agent.description == "A test agent"
      assert agent.goal == "Testing"
    end

    test "create_agent/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Agents.create_agent(@invalid_attrs)
    end

    test "update_agent/2 with valid data updates the agent" do
      agent = agent_fixture()
      assert {:ok, %Agent{} = agent} = Agents.update_agent(agent, @update_attrs)
      assert agent.name == "Updated Agent"
      assert agent.description == "An updated test agent"
      assert agent.goal == "Updated Testing"
    end

    test "update_agent/2 with invalid data returns error changeset" do
      agent = agent_fixture()
      assert {:error, %Ecto.Changeset{}} = Agents.update_agent(agent, @invalid_attrs)
      assert agent == Agents.get_agent!(agent.id)
    end

    test "delete_agent/1 deletes the agent" do
      agent = agent_fixture()
      assert {:ok, %Agent{}} = Agents.delete_agent(agent)
      assert_raise Ecto.NoResultsError, fn -> Agents.get_agent!(agent.id) end
    end

    test "change_agent/1 returns a agent changeset" do
      agent = agent_fixture()
      assert %Ecto.Changeset{} = Agents.change_agent(agent)
    end
  end
end
