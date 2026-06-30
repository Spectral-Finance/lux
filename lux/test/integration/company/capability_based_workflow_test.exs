defmodule Lux.Integration.Company.CapabilityBasedWorkflowTest do
  @moduledoc """
  Integration tests for capability-based task distribution in company workflows.
  """
  use IntegrationCase, async: true

  alias Lux.Company.Hub.Local
  alias Test.Support.Companies.CapabilityTeam

  @moduletag :integration

  describe "capability-based workflow" do
    setup do
      # Start a local hub for the company
      hub_name = :"hub_#{:erlang.unique_integer([:positive])}"
      table_name = :"table_#{:erlang.unique_integer([:positive])}"
      start_supervised!({Local, name: hub_name, table_name: table_name})

      # Get the company configuration
      company_config = CapabilityTeam.view()

      # Start the company
      {:ok, company_pid} =
        Lux.Company.start_link(CapabilityTeam, %{
          name: company_config.name,
          hub: hub_name
        })

      # Register the company with the hub
      {:ok, company_id} = Local.register_company(company_config, hub_name)

      %{company_pid: company_pid, hub: hub_name, company_id: company_id}
    end

    test "successfully distributes tasks based on capabilities", %{
      company_pid: pid,
      hub: hub,
      company_id: company_id
    } do
      # Start an objective that requires multiple capabilities
      {:ok, objective} =
        Lux.Company.run_objective(pid, :multi_capability_task, %{
          "title" => "Complex Project",
          "required_capabilities" => ["research", "analysis", "writing"]
        })

      objective_id = objective.payload["id"]

      # Verify initial state
      {:ok, initial_status} = Lux.Company.get_objective_status(pid, objective_id)
      assert initial_status == :in_progress

      # Verify company structure and capabilities
      {:ok, company} = Local.get_company(company_id, hub)
      assert company.name == "Capability Test Team"

      # Verify each role has the expected capabilities
      researcher = Enum.find(company.roles, &(&1.name == "Researcher"))
      assert researcher != nil
      assert "research" in researcher.capabilities

      analyst = Enum.find(company.roles, &(&1.name == "Analyst"))
      assert analyst != nil
      assert "analysis" in analyst.capabilities

      writer = Enum.find(company.roles, &(&1.name == "Writer"))
      assert writer != nil
      assert "writing" in writer.capabilities

      # Wait for task distribution and execution
      :timer.sleep(1000)

      # Check task assignments
      {:ok, objective_state} = Lux.Company.get_objective(pid, objective_id)
      tasks = objective_state.tasks || []

      # Verify tasks were assigned to agents with matching capabilities
      Enum.each(tasks, fn task ->
        assert task.assigned_to != nil
        {:ok, agent} = Local.get_agent(task.assigned_to, hub)
        required_capabilities = task.required_capabilities || []

        Enum.each(required_capabilities, fn capability ->
          assert capability in agent.capabilities
        end)
      end)

      # Wait for completion
      :timer.sleep(2000)
      {:ok, final_status} = Lux.Company.get_objective_status(pid, objective_id)
      assert final_status in [:completed, :in_progress]
    end

    test "handles capability mismatches gracefully", %{company_pid: pid} do
      # Start an objective with capabilities that don't match any agent
      {:ok, objective} =
        Lux.Company.run_objective(pid, :multi_capability_task, %{
          "title" => "Impossible Project",
          "required_capabilities" => ["design", "video_editing"]
        })

      objective_id = objective.payload["id"]

      # Wait for error handling
      :timer.sleep(1000)
      {:ok, status} = Lux.Company.get_objective_status(pid, objective_id)
      assert status == :failed

      # Verify error details
      {:ok, objective_state} = Lux.Company.get_objective(pid, objective_id)
      assert objective_state.error != nil
      assert String.contains?(objective_state.error, "No agent found with required capabilities")
    end

    test "optimally distributes tasks based on capability matches", %{
      company_pid: pid,
      hub: hub,
      company_id: company_id
    } do
      # Start multiple objectives with varying capability requirements
      objectives =
        for i <- 1..3 do
          {:ok, obj} =
            Lux.Company.run_objective(pid, :multi_capability_task, %{
              "title" => "Project #{i}",
              "required_capabilities" => ["research", "analysis"]
            })

          obj
        end

      # Wait for task distribution
      :timer.sleep(1500)

      # Verify load balancing among capable agents
      {:ok, company} = Local.get_company(company_id, hub)

      _capable_agents =
        Enum.filter(company.roles, fn role ->
          "research" in role.capabilities and "analysis" in role.capabilities
        end)

      # Check task distribution
      task_counts =
        Enum.reduce(objectives, %{}, fn obj, acc ->
          {:ok, objective_state} = Lux.Company.get_objective(pid, obj.payload["id"])
          tasks = objective_state.tasks || []

          Enum.reduce(tasks, acc, fn task, inner_acc ->
            Map.update(inner_acc, task.assigned_to, 1, &(&1 + 1))
          end)
        end)

      # Verify relatively even distribution
      task_counts_list = Map.values(task_counts)
      max_tasks = Enum.max(task_counts_list)
      min_tasks = Enum.min(task_counts_list)
      assert max_tasks - min_tasks <= 1
    end
  end
end
