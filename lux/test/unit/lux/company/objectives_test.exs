defmodule Lux.Company.ObjectivesTest do
  use UnitCase, async: true

  alias Lux.Company.Objectives

  @moduletag :unit

  describe "create/1" do
    test "creates an objective with required attributes" do
      attrs = %{
        name: :test_objective,
        description: "Test objective description"
      }

      assert {:ok, objective} = Objectives.create(attrs)
      assert objective.name == :test_objective
      assert objective.description == "Test objective description"
      assert is_binary(objective.id)
      assert objective.status == :pending
      assert objective.progress == 0
      assert objective.assigned_agents == []
    end

    test "creates an objective with all attributes" do
      attrs = %{
        name: :test_objective,
        description: "Test objective description",
        success_criteria: "Test completed successfully",
        steps: ["Step 1", "Step 2"],
        metadata: %{priority: :high}
      }

      assert {:ok, objective} = Objectives.create(attrs)
      assert objective.success_criteria == "Test completed successfully"
      assert objective.steps == ["Step 1", "Step 2"]
      assert objective.metadata.priority == :high
    end

    test "returns error with invalid attributes" do
      assert {:error, :invalid_attributes} = Objectives.create(%{name: :test})
      assert {:error, :invalid_attributes} = Objectives.create(%{description: "test"})
      assert {:error, :invalid_attributes} = Objectives.create("invalid")
    end
  end

  describe "assign_agent/2" do
    setup do
      {:ok, objective} =
        Objectives.create(%{
          name: :test_objective,
          description: "Test objective"
        })

      %{objective: objective}
    end

    test "assigns an agent to the objective", %{objective: objective} do
      agent_id = "agent-123"
      assert {:ok, updated} = Objectives.assign_agent(objective, agent_id)
      assert agent_id in updated.assigned_agents
    end

    test "prevents duplicate agent assignments", %{objective: objective} do
      agent_id = "agent-123"
      {:ok, with_agent} = Objectives.assign_agent(objective, agent_id)
      assert {:error, :already_assigned} = Objectives.assign_agent(with_agent, agent_id)
    end
  end

  describe "start/1" do
    setup do
      {:ok, objective} =
        Objectives.create(%{
          name: :test_objective,
          description: "Test objective"
        })

      %{objective: objective}
    end

    test "starts an objective with assigned agents", %{objective: objective} do
      {:ok, with_agent} = Objectives.assign_agent(objective, "agent-123")
      assert {:ok, started} = Objectives.start(with_agent)
      assert started.status == :in_progress
      refute is_nil(started.started_at)
    end

    test "prevents starting without agents", %{objective: objective} do
      assert {:error, :no_agents_assigned} = Objectives.start(objective)
    end

    test "prevents starting non-pending objectives", %{objective: objective} do
      {:ok, with_agent} = Objectives.assign_agent(objective, "agent-123")
      {:ok, started} = Objectives.start(with_agent)
      assert {:error, :invalid_status} = Objectives.start(started)
    end
  end

  describe "update_progress/2" do
    setup do
      {:ok, objective} =
        Objectives.create(%{
          name: :test_objective,
          description: "Test objective"
        })

      {:ok, with_agent} = Objectives.assign_agent(objective, "agent-123")
      {:ok, started} = Objectives.start(with_agent)

      %{objective: started}
    end

    test "updates progress of in-progress objective", %{objective: objective} do
      assert {:ok, updated} = Objectives.update_progress(objective, 50)
      assert updated.progress == 50
    end

    test "validates progress range", %{objective: objective} do
      assert {:error, :invalid_progress} = Objectives.update_progress(objective, -1)
      assert {:error, :invalid_progress} = Objectives.update_progress(objective, 101)
    end
  end

  describe "complete/1" do
    setup do
      {:ok, objective} =
        Objectives.create(%{
          name: :test_objective,
          description: "Test objective"
        })

      {:ok, with_agent} = Objectives.assign_agent(objective, "agent-123")
      {:ok, started} = Objectives.start(with_agent)

      %{objective: started}
    end

    test "completes an in-progress objective", %{objective: objective} do
      assert {:ok, completed} = Objectives.complete(objective)
      assert completed.status == :completed
      assert completed.progress == 100
      refute is_nil(completed.completed_at)
    end

    test "prevents completing non-in-progress objectives" do
      {:ok, pending} =
        Objectives.create(%{
          name: :test_objective,
          description: "Test objective"
        })

      assert {:error, :invalid_status} = Objectives.complete(pending)
    end
  end

  describe "fail/2" do
    setup do
      {:ok, objective} =
        Objectives.create(%{
          name: :test_objective,
          description: "Test objective"
        })

      {:ok, with_agent} = Objectives.assign_agent(objective, "agent-123")
      {:ok, started} = Objectives.start(with_agent)

      %{objective: started}
    end

    test "fails an in-progress objective", %{objective: objective} do
      reason = "Resource unavailable"
      assert {:ok, failed} = Objectives.fail(objective, reason)
      assert failed.status == :failed
      refute is_nil(failed.completed_at)
      assert failed.metadata.failure_reason == reason
    end

    test "prevents failing non-in-progress objectives" do
      {:ok, pending} =
        Objectives.create(%{
          name: :test_objective,
          description: "Test objective"
        })

      assert {:error, :invalid_status} = Objectives.fail(pending)
    end
  end

  describe "status checks" do
    setup do
      {:ok, objective} =
        Objectives.create(%{
          name: :test_objective,
          description: "Test objective"
        })

      {:ok, with_agent} = Objectives.assign_agent(objective, "agent-123")

      %{
        pending: objective,
        with_agent: with_agent
      }
    end

    test "can_start?/1", %{pending: pending, with_agent: with_agent} do
      refute Objectives.can_start?(pending)
      assert Objectives.can_start?(with_agent)
    end

    test "active?/1", %{with_agent: with_agent} do
      refute Objectives.active?(with_agent)
      {:ok, started} = Objectives.start(with_agent)
      assert Objectives.active?(started)
    end

    test "completed?/1", %{with_agent: with_agent} do
      {:ok, started} = Objectives.start(with_agent)
      refute Objectives.completed?(started)
      {:ok, completed} = Objectives.complete(started)
      assert Objectives.completed?(completed)
    end

    test "failed?/1", %{with_agent: with_agent} do
      {:ok, started} = Objectives.start(with_agent)
      refute Objectives.failed?(started)
      {:ok, failed} = Objectives.fail(started, "error")
      assert Objectives.failed?(failed)
    end
  end

  describe "duration/1" do
    setup do
      {:ok, objective} =
        Objectives.create(%{
          name: :test_objective,
          description: "Test objective"
        })

      {:ok, with_agent} = Objectives.assign_agent(objective, "agent-123")

      %{objective: with_agent}
    end

    test "returns nil for non-started objectives", %{objective: objective} do
      assert Objectives.duration(objective) == nil
    end

    test "returns duration for in-progress objectives", %{objective: objective} do
      {:ok, started} = Objectives.start(objective)
      :timer.sleep(1000)
      duration = Objectives.duration(started)
      assert duration >= 1
    end

    test "returns final duration for completed objectives", %{objective: objective} do
      {:ok, started} = Objectives.start(objective)
      :timer.sleep(1000)
      {:ok, completed} = Objectives.complete(started)
      duration = Objectives.duration(completed)
      assert duration >= 1
    end
  end
end
