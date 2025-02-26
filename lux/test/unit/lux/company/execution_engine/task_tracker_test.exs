defmodule Lux.Company.ExecutionEngine.TaskTrackerTest do
  use UnitCase, async: true

  alias Lux.Company.ExecutionEngine.TaskTracker

  setup do
    # Create a unique registry for test isolation
    registry_name = :"test_registry_#{:erlang.unique_integer([:positive])}"
    {:ok, _} = Registry.start_link(keys: :unique, name: registry_name)

    # Create a mock company process that collects messages
    test_pid = self()
    company_pid = spawn_link(fn -> company_process(test_pid, []) end)

    # Generate a unique objective ID for test isolation
    objective_id = "objective_#{:erlang.unique_integer([:positive])}"

    # Start the task registry
    task_registry_name = Module.concat(objective_id, TaskRegistry)
    {:ok, _} = Registry.start_link(keys: :unique, name: task_registry_name)

    # Start the task tracker
    {:ok, tracker} =
      TaskTracker.start_link(
        objective_id: objective_id,
        company_pid: company_pid
      )

    {:ok,
     tracker: tracker,
     company_pid: company_pid,
     objective_id: objective_id,
     registry: registry_name}
  end

  describe "task creation" do
    test "creates a new task", %{tracker: tracker} do
      assert {:ok, task_id} = TaskTracker.create_task(tracker, "Step 1")
      assert {:ok, task} = TaskTracker.get_task(tracker, task_id)
      assert task.step == "Step 1"
      assert task.status == :pending
    end

    test "notifies company of task creation", %{tracker: tracker, objective_id: objective_id} do
      {:ok, task_id} = TaskTracker.create_task(tracker, "Step 1")
      assert_receive {:task_tracker_update, ^objective_id, {:task_created, %{id: ^task_id}}}
    end
  end

  describe "task assignment" do
    setup %{tracker: tracker} do
      {:ok, task_id} = TaskTracker.create_task(tracker, "Step 1")
      {:ok, task_id: task_id}
    end

    test "assigns task to agent", %{tracker: tracker, task_id: task_id} do
      assert :ok = TaskTracker.assign_task(tracker, task_id, "agent_1")
      assert {:ok, task} = TaskTracker.get_task(tracker, task_id)
      assert task.assigned_agent == "agent_1"
      assert task.status == :assigned
    end

    test "lists tasks for agent", %{tracker: tracker, task_id: task_id} do
      :ok = TaskTracker.assign_task(tracker, task_id, "agent_1")
      assert {:ok, tasks} = TaskTracker.list_agent_tasks(tracker, "agent_1")
      assert length(tasks) == 1
      assert hd(tasks).id == task_id
    end

    test "prevents reassignment of assigned task", %{tracker: tracker, task_id: task_id} do
      :ok = TaskTracker.assign_task(tracker, task_id, "agent_1")

      assert {:error, {:invalid_status, :assigned, [:pending]}} =
               TaskTracker.assign_task(tracker, task_id, "agent_2")
    end
  end

  describe "task execution" do
    setup %{tracker: tracker} do
      {:ok, task_id} = TaskTracker.create_task(tracker, "Step 1")
      :ok = TaskTracker.assign_task(tracker, task_id, "agent_1")
      {:ok, task_id: task_id}
    end

    test "starts task execution", %{tracker: tracker, task_id: task_id} do
      assert :ok = TaskTracker.start_task(tracker, task_id, "agent_1")
      assert {:ok, task} = TaskTracker.get_task(tracker, task_id)
      assert task.status == :in_progress
      assert task.started_at != nil
    end

    test "prevents wrong agent from starting task", %{tracker: tracker, task_id: task_id} do
      assert {:error, :wrong_agent} = TaskTracker.start_task(tracker, task_id, "agent_2")
    end

    test "completes task with result", %{tracker: tracker, task_id: task_id} do
      :ok = TaskTracker.start_task(tracker, task_id, "agent_1")
      assert :ok = TaskTracker.complete_task(tracker, task_id, %{output: "success"})
      assert {:ok, task} = TaskTracker.get_task(tracker, task_id)
      assert task.status == :completed
      assert task.completed_at != nil
      assert task.result == %{output: "success"}
    end

    test "fails task with error", %{tracker: tracker, task_id: task_id} do
      :ok = TaskTracker.start_task(tracker, task_id, "agent_1")
      assert :ok = TaskTracker.fail_task(tracker, task_id, "error message")
      assert {:ok, task} = TaskTracker.get_task(tracker, task_id)
      assert task.status == :failed
      assert task.completed_at != nil
      assert task.error == "error message"
    end
  end

  describe "task listing" do
    test "lists all tasks", %{tracker: tracker} do
      {:ok, task_id1} = TaskTracker.create_task(tracker, "Step 1")
      {:ok, task_id2} = TaskTracker.create_task(tracker, "Step 2")

      assert {:ok, tasks} = TaskTracker.list_tasks(tracker)
      assert length(tasks) == 2
      assert tasks |> Enum.map(& &1.id) |> Enum.sort() == Enum.sort([task_id1, task_id2])
    end

    test "handles empty task list", %{tracker: tracker} do
      assert {:ok, tasks} = TaskTracker.list_tasks(tracker)
      assert tasks == []
    end
  end

  describe "error handling" do
    test "handles non-existent task", %{tracker: tracker} do
      assert {:error, :task_not_found} = TaskTracker.get_task(tracker, "nonexistent")
    end

    test "validates task status transitions", %{tracker: tracker} do
      {:ok, task_id} = TaskTracker.create_task(tracker, "Step 1")

      assert {:error, {:invalid_status, :pending, [:in_progress]}} =
               TaskTracker.complete_task(tracker, task_id, %{})
    end
  end

  # Helper function to simulate company process
  defp company_process(test_pid, messages) do
    receive do
      message ->
        send(test_pid, message)
        company_process(test_pid, [message | messages])
    end
  end
end
