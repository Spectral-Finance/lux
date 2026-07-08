defmodule Lux.Company.ExecutionEngine.TaskTracker do
  @moduledoc """
  Tracks and manages concurrent task execution within an objective.

  This module is responsible for:
  - Tracking multiple concurrent tasks
  - Recording agent assignments
  - Maintaining task status and progress
  - Logging task lifecycle events
  """

  use GenServer

  require Logger

  @type task_id :: String.t()
  @type agent_id :: String.t()
  @type task_status :: :pending | :assigned | :in_progress | :completed | :failed

  @type task :: %{
          id: task_id(),
          step: String.t(),
          assigned_agent: agent_id() | nil,
          status: task_status(),
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          error: term() | nil,
          result: term() | nil,
          metadata: map()
        }

  @type state :: %{
          objective_id: String.t(),
          tasks: %{task_id() => task()},
          agent_tasks: %{agent_id() => MapSet.t(task_id())},
          company_pid: pid()
        }

  # Client API

  @doc """
  Starts a new TaskTracker for an objective.

  ## Options
  - :objective_id - The ID of the objective these tasks belong to
  - :company_pid - PID of the company process for notifications
  """
  def start_link(opts) do
    objective_id = Keyword.fetch!(opts, :objective_id)
    name = via_tuple(objective_id)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Creates a new task for a specific step.
  """
  def create_task(tracker, step) do
    GenServer.call(tracker, {:create_task, step})
  end

  @doc """
  Assigns a task to an agent.
  """
  def assign_task(tracker, task_id, agent_id) do
    GenServer.call(tracker, {:assign_task, task_id, agent_id})
  end

  @doc """
  Marks a task as started by an agent.
  """
  def start_task(tracker, task_id, agent_id) do
    GenServer.call(tracker, {:start_task, task_id, agent_id})
  end

  @doc """
  Marks a task as completed with a result.
  """
  def complete_task(tracker, task_id, result) do
    GenServer.call(tracker, {:complete_task, task_id, result})
  end

  @doc """
  Marks a task as failed with an error reason.
  """
  def fail_task(tracker, task_id, error) do
    GenServer.call(tracker, {:fail_task, task_id, error})
  end

  @doc """
  Lists all tasks for an agent.
  """
  def list_agent_tasks(tracker, agent_id) do
    GenServer.call(tracker, {:list_agent_tasks, agent_id})
  end

  @doc """
  Lists all tasks with their current status.
  """
  def list_tasks(tracker) do
    GenServer.call(tracker, :list_tasks)
  end

  @doc """
  Gets detailed information about a specific task.
  """
  def get_task(tracker, task_id) do
    GenServer.call(tracker, {:get_task, task_id})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.debug("Initializing TaskTracker with opts: #{inspect(opts)}")

    state = %{
      objective_id: Keyword.fetch!(opts, :objective_id),
      company_pid: Keyword.fetch!(opts, :company_pid),
      tasks: %{},
      agent_tasks: %{}
    }

    Logger.debug("Initial state: #{inspect(state)}")
    {:ok, state}
  end

  @impl true
  def handle_call({:create_task, step}, _from, state) do
    task_id = "task_#{:erlang.unique_integer([:positive])}"

    task = %{
      id: task_id,
      step: step,
      assigned_agent: nil,
      status: :pending,
      started_at: nil,
      completed_at: nil,
      error: nil,
      result: nil,
      metadata: %{}
    }

    Logger.debug("Creating new task: #{inspect(task)}")
    new_state = put_in(state.tasks[task_id], task)
    notify_company(new_state, {:task_created, task})

    {:reply, {:ok, task_id}, new_state}
  end

  def handle_call({:assign_task, task_id, agent_id}, _from, state) do
    with {:ok, task} <- get_task_from_state(state, task_id),
         :ok <- validate_task_status(task, [:pending]) do
      Logger.debug("Assigning task #{task_id} to agent #{agent_id}")

      updated_task = %{task | assigned_agent: agent_id, status: :assigned}

      new_state =
        state
        |> put_in([:tasks, task_id], updated_task)
        |> update_agent_tasks(agent_id, task_id)

      notify_company(new_state, {:task_assigned, updated_task})
      {:reply, :ok, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:start_task, task_id, agent_id}, _from, state) do
    with {:ok, task} <- get_task_from_state(state, task_id),
         :ok <- validate_task_agent(task, agent_id),
         :ok <- validate_task_status(task, [:assigned]) do
      Logger.debug("Starting task #{task_id} by agent #{agent_id}")

      updated_task = %{task | status: :in_progress, started_at: DateTime.utc_now()}

      new_state = put_in(state.tasks[task_id], updated_task)
      notify_company(new_state, {:task_started, updated_task})
      {:reply, :ok, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:complete_task, task_id, result}, _from, state) do
    with {:ok, task} <- get_task_from_state(state, task_id),
         :ok <- validate_task_status(task, [:in_progress]) do
      Logger.debug("Completing task #{task_id} with result: #{inspect(result)}")

      updated_task = %{
        task
        | status: :completed,
          completed_at: DateTime.utc_now(),
          result: result
      }

      new_state = put_in(state.tasks[task_id], updated_task)
      notify_company(new_state, {:task_completed, updated_task})
      {:reply, :ok, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:fail_task, task_id, error}, _from, state) do
    with {:ok, task} <- get_task_from_state(state, task_id),
         :ok <- validate_task_status(task, [:in_progress]) do
      Logger.debug("Failing task #{task_id} with error: #{inspect(error)}")

      updated_task = %{task | status: :failed, completed_at: DateTime.utc_now(), error: error}

      new_state = put_in(state.tasks[task_id], updated_task)
      notify_company(new_state, {:task_failed, updated_task})
      {:reply, :ok, new_state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:list_agent_tasks, agent_id}, _from, state) do
    task_ids = Map.get(state.agent_tasks, agent_id, MapSet.new())
    tasks = Enum.map(task_ids, &Map.get(state.tasks, &1))
    {:reply, {:ok, tasks}, state}
  end

  def handle_call(:list_tasks, _from, state) do
    {:reply, {:ok, Map.values(state.tasks)}, state}
  end

  def handle_call({:get_task, task_id}, _from, state) do
    case get_task_from_state(state, task_id) do
      {:ok, task} -> {:reply, {:ok, task}, state}
      error -> {:reply, error, state}
    end
  end

  # Private Functions

  defp via_tuple(objective_id) do
    {:via, Registry, {Module.concat(objective_id, TaskRegistry), "task_tracker"}}
  end

  defp get_task_from_state(state, task_id) do
    case Map.get(state.tasks, task_id) do
      nil -> {:error, :task_not_found}
      task -> {:ok, task}
    end
  end

  defp validate_task_status(task, valid_statuses) do
    if task.status in valid_statuses do
      :ok
    else
      {:error, {:invalid_status, task.status, valid_statuses}}
    end
  end

  defp validate_task_agent(task, agent_id) do
    if task.assigned_agent == agent_id do
      :ok
    else
      {:error, :wrong_agent}
    end
  end

  defp update_agent_tasks(state, agent_id, task_id) do
    agent_tasks = Map.get(state.agent_tasks, agent_id, MapSet.new())
    put_in(state.agent_tasks[agent_id], MapSet.put(agent_tasks, task_id))
  end

  defp notify_company(state, event) do
    send(state.company_pid, {:task_tracker_update, state.objective_id, event})
  end
end
