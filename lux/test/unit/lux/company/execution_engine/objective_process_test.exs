defmodule Lux.Company.ExecutionEngine.ObjectiveProcessTest do
  use UnitCase, async: true

  alias Lux.Company.ExecutionEngine.ArtifactStore
  alias Lux.Company.ExecutionEngine.ObjectiveProcess
  alias Lux.Company.ExecutionEngine.TaskTracker
  alias Lux.Company.Objective

  setup do
    # Create a test registry with a unique name for test isolation
    registry_name = :"test_registry_#{:erlang.unique_integer([:positive])}"
    {:ok, _} = Registry.start_link(keys: :unique, name: registry_name)

    # Create a test objective
    {:ok, objective} =
      Objective.new(%{
        name: :test_objective,
        description: "Test objective",
        success_criteria: "Test completed",
        steps: ["Step 1", "Step 2"],
        input_schema: %{
          required: ["test_input"],
          properties: %{
            "test_input" => %{type: "string"}
          }
        }
      })

    # Create a mock company process
    test_pid = self()
    company_pid = spawn_link(fn -> company_process(test_pid, []) end)

    # Generate a unique objective ID for test isolation
    objective_id = "objective_#{:erlang.unique_integer([:positive])}"

    # Start task tracker registry
    task_registry_name = Module.concat(objective_id, TaskRegistry)
    {:ok, _} = Registry.start_link(keys: :unique, name: task_registry_name)

    # Start artifact store registry
    artifact_registry_name = Module.concat(objective_id, ArtifactRegistry)
    {:ok, _} = Registry.start_link(keys: :unique, name: artifact_registry_name)

    # Start task tracker
    {:ok, task_tracker} =
      TaskTracker.start_link(
        objective_id: objective_id,
        company_pid: company_pid
      )

    # Start artifact store
    {:ok, artifact_store} =
      ArtifactStore.start_link(
        objective_id: objective_id,
        company_pid: company_pid
      )

    # Start the objective process
    {:ok, pid} =
      ObjectiveProcess.start_link(
        objective_id: objective_id,
        objective: objective,
        company_pid: company_pid,
        input: %{"test_input" => "value"},
        registry: registry_name
      )

    {:ok,
     pid: pid,
     objective: objective,
     company_pid: company_pid,
     registry: registry_name,
     objective_id: objective_id,
     task_tracker: task_tracker,
     artifact_store: artifact_store}
  end

  describe "initialization" do
    test "starts in pending state", %{pid: pid} do
      assert %{status: :pending} = :sys.get_state(pid)
    end

    test "has correct initial values", %{pid: pid, objective: objective} do
      state = :sys.get_state(pid)
      assert state.objective == objective
      assert state.progress == 0
      assert state.current_step == nil
      assert state.error == nil
    end

    test "connects to task tracker and artifact store", %{
      pid: pid,
      task_tracker: task_tracker,
      artifact_store: artifact_store
    } do
      state = :sys.get_state(pid)
      assert state.task_tracker == task_tracker
      assert state.artifact_store == artifact_store
    end
  end

  describe "state transitions" do
    test "transitions from pending to initializing", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      assert %{status: :initializing} = :sys.get_state(pid)
    end

    test "transitions from initializing to in_progress", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      assert %{status: :in_progress} = :sys.get_state(pid)
    end

    test "transitions to completed state", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      :ok = ObjectiveProcess.complete(pid)
      assert %{status: :completed} = :sys.get_state(pid)
    end

    test "transitions to failed state", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      :ok = ObjectiveProcess.fail(pid, "Test failure")
      state = :sys.get_state(pid)
      assert state.status == :failed
      assert state.error == "Test failure"
    end

    test "transitions to cancelled state", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      :ok = ObjectiveProcess.cancel(pid)
      assert %{status: :cancelled} = :sys.get_state(pid)
    end
  end

  describe "progress tracking" do
    test "updates progress", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      :ok = ObjectiveProcess.update_progress(pid, 50)
      assert %{progress: 50} = :sys.get_state(pid)
    end

    test "validates progress value", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      assert {:error, :invalid_progress} = ObjectiveProcess.update_progress(pid, 101)
      assert {:error, :invalid_progress} = ObjectiveProcess.update_progress(pid, -1)
    end
  end

  describe "step management" do
    test "updates current step", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      :ok = ObjectiveProcess.set_current_step(pid, "Step 1")
      assert %{current_step: "Step 1"} = :sys.get_state(pid)
    end

    test "validates step exists in objective", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      assert {:error, :invalid_step} = ObjectiveProcess.set_current_step(pid, "Invalid Step")
    end
  end

  describe "error handling" do
    test "adds error to state", %{pid: pid} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      :ok = ObjectiveProcess.add_error(pid, "Test error")
      assert %{error: "Test error"} = :sys.get_state(pid)
    end
  end

  describe "component access" do
    test "provides access to task tracker", %{pid: pid, task_tracker: task_tracker} do
      assert {:ok, ^task_tracker} = ObjectiveProcess.get_task_tracker(pid)
    end

    test "provides access to artifact store", %{pid: pid, artifact_store: artifact_store} do
      assert {:ok, ^artifact_store} = ObjectiveProcess.get_artifact_store(pid)
    end

    test "integrates with task tracker", %{pid: pid, task_tracker: task_tracker} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      :ok = ObjectiveProcess.set_current_step(pid, "Step 1")

      # Create and manage tasks through task tracker
      {:ok, task_id} = TaskTracker.create_task(task_tracker, "Step 1")
      :ok = TaskTracker.assign_task(task_tracker, task_id, "agent_1")
      :ok = TaskTracker.start_task(task_tracker, task_id, "agent_1")
      :ok = TaskTracker.complete_task(task_tracker, task_id, %{output: "success"})

      # Verify task was created and completed
      {:ok, task} = TaskTracker.get_task(task_tracker, task_id)
      assert task.status == :completed
      assert task.step == "Step 1"
    end

    test "integrates with artifact store", %{pid: pid, artifact_store: artifact_store} do
      :ok = ObjectiveProcess.initialize(pid)
      :ok = ObjectiveProcess.start(pid)
      :ok = ObjectiveProcess.set_current_step(pid, "Step 1")

      # Create and manage artifacts through artifact store
      {:ok, artifact_id} =
        ArtifactStore.store_artifact(
          artifact_store,
          "test_artifact",
          "test content",
          "text/plain",
          step_id: "Step 1"
        )

      # Verify artifact was stored
      {:ok, artifact} = ArtifactStore.get_artifact(artifact_store, artifact_id)
      assert artifact.name == "test_artifact"
      assert artifact.step_id == "Step 1"
    end
  end

  describe "process registration" do
    test "registers with the registry", %{
      pid: pid,
      registry: registry,
      objective_id: objective_id
    } do
      [{registered_pid, nil}] = Registry.lookup(registry, objective_id)
      assert registered_pid == pid
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
