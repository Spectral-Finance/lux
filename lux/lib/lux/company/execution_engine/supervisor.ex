defmodule Lux.Company.ExecutionEngine.Supervisor do
  @moduledoc """
  Supervisor for the Objective Execution Engine.

  This supervisor manages:
  1. A Registry for tracking objective processes
  2. A DynamicSupervisor for managing objective processes
  3. A Registry for task trackers
  4. A Registry for artifact stores
  5. A DynamicSupervisor for task trackers and artifact stores
  """

  use Supervisor

  alias Lux.Company.ExecutionEngine.ArtifactStore
  alias Lux.Company.ExecutionEngine.ObjectiveProcess
  alias Lux.Company.ExecutionEngine.TaskTracker

  require Logger

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Logger.debug("Starting ExecutionEngine.Supervisor with name: #{inspect(name)}")
    Logger.debug("Supervisor start options: #{inspect(opts)}")
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Starts a new objective process under this supervisor.

  Returns `{:ok, pid}` if successful, `{:error, reason}` otherwise.
  """
  def start_objective(supervisor, objective, company_pid, input, objective_id \\ nil) do
    Logger.debug("Starting objective process #{objective_id} under supervisor #{supervisor}")
    Logger.debug("Objective details: #{inspect(objective)}")
    Logger.debug("Company PID: #{inspect(company_pid)}")
    Logger.debug("Input: #{inspect(input)}")

    # Generate a unique objective ID if none provided
    objective_id = objective_id || "objective_#{:erlang.unique_integer([:positive])}"

    # Validate objective ID format
    if valid_objective_id?(objective_id) do
      registry = Module.concat(supervisor, Registry)
      objective_supervisor = Module.concat(supervisor, ObjectiveSupervisor)
      component_supervisor = Module.concat(supervisor, ComponentSupervisor)

      Logger.debug("Using registry: #{inspect(registry)}")
      Logger.debug("Using supervisor: #{inspect(objective_supervisor)}")

      # Start task registry
      task_registry = Module.concat(objective_id, TaskRegistry)
      artifact_registry = Module.concat(objective_id, ArtifactRegistry)

      Logger.debug("Using task registry: #{inspect(task_registry)}")
      Logger.debug("Using artifact registry: #{inspect(artifact_registry)}")
      Logger.debug("Using component supervisor: #{inspect(component_supervisor)}")

      # Start component registries first
      with {:ok, _} <- Registry.start_link(keys: :unique, name: task_registry),
           {:ok, _} <- Registry.start_link(keys: :unique, name: artifact_registry),
           # Start task tracker
           {:ok, _task_tracker} <-
             DynamicSupervisor.start_child(
               component_supervisor,
               {TaskTracker, objective_id: objective_id, company_pid: company_pid}
             ),
           # Start artifact store
           {:ok, _artifact_store} <-
             DynamicSupervisor.start_child(
               component_supervisor,
               {ArtifactStore, objective_id: objective_id, company_pid: company_pid}
             ),
           # Start objective process
           {:ok, pid} <-
             DynamicSupervisor.start_child(
               objective_supervisor,
               {ObjectiveProcess,
                [
                  objective_id: objective_id,
                  objective: objective,
                  company_pid: company_pid,
                  input: input,
                  registry: registry
                ]}
             ) do
        Logger.debug(
          "Registering process in supervisor. PID: #{inspect(pid)}, objective_id: #{objective_id}"
        )

        Logger.debug(
          "Current registry entries: #{inspect(Registry.select(registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}]))}"
        )

        # Register the process with pid as key and objective_id as value
        Registry.register(registry, pid, objective_id)

        Logger.debug(
          "After registration - registry entries: #{inspect(Registry.select(registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}]))}"
        )

        {:ok, pid}
      else
        error ->
          Logger.error("Failed to start objective process: #{inspect(error)}")
          cleanup_components(task_registry, artifact_registry)
          error
      end
    else
      Logger.error("Invalid objective ID format: #{inspect(objective_id)}")
      {:error, :invalid_objective_id}
    end
  end

  @doc """
  Stops an objective process and its associated components managed by this supervisor.

  Returns `:ok` if successful, `{:error, reason}` otherwise.
  """
  def stop_objective(supervisor, objective_id) do
    Logger.debug("Stopping objective #{objective_id}")
    registry = Module.concat(supervisor, Registry)

    Logger.debug("Looking up in registry: #{inspect(registry)}")

    Logger.debug(
      "Current registry entries: #{inspect(Registry.select(registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}]))}"
    )

    # Find the process by objective_id
    case Registry.select(registry, [{{:"$1", :"$2", objective_id}, [], [:"$1"]}]) do
      [pid] ->
        Logger.debug("Found process #{inspect(pid)}, terminating...")

        # Stop component processes first
        task_registry = Module.concat(objective_id, TaskRegistry)
        artifact_registry = Module.concat(objective_id, ArtifactRegistry)

        # Terminate registries and their processes
        cleanup_components(task_registry, artifact_registry)

        # Then terminate the objective process
        result =
          DynamicSupervisor.terminate_child(Module.concat(supervisor, ObjectiveSupervisor), pid)

        Logger.debug("Termination result: #{inspect(result)}")
        result

      [] ->
        Logger.error("No process found for objective #{objective_id}")
        {:error, :not_found}
    end
  end

  @doc """
  Lists all running objective processes under this supervisor.

  Returns a list of objective IDs.
  """
  def list_objectives(supervisor) do
    Logger.debug(
      "Listing objectives from registry: #{inspect(Module.concat(supervisor, Registry))}"
    )

    registry = Module.concat(supervisor, Registry)
    entries = Registry.select(registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    Logger.debug("All registry entries: #{inspect(entries)}")

    # Only return entries where the key is a string (objective_id)
    entries
    |> Enum.filter(fn {key, _value, _} -> is_binary(key) end)
    |> Enum.map(fn {key, _value, _} -> key end)
  end

  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Logger.debug("Initializing supervisor #{inspect(name)}")
    Logger.debug("Initialization options: #{inspect(opts)}")

    children = [
      # Registry for tracking objective processes
      {Registry, keys: :unique, name: Module.concat(name, Registry)},

      # DynamicSupervisor for managing objective processes
      {DynamicSupervisor, strategy: :one_for_one, name: Module.concat(name, ObjectiveSupervisor)},

      # DynamicSupervisor for managing task trackers and artifact stores
      {DynamicSupervisor, strategy: :one_for_one, name: Module.concat(name, ComponentSupervisor)}
    ]

    Logger.debug("Starting children: #{inspect(children)}")
    Supervisor.init(children, strategy: :one_for_all)
  end

  # Private Functions

  defp cleanup_registry(name) do
    case Process.whereis(name) do
      nil ->
        Logger.debug("Registry #{inspect(name)} already terminated")
        :ok

      pid ->
        Logger.debug("Terminating registry #{inspect(name)}")
        Process.exit(pid, :normal)
        :ok
    end
  end

  defp cleanup_components(task_registry, artifact_registry) do
    # Terminate task registry and its processes
    Logger.debug("Terminating registry #{inspect(task_registry)}")

    case Registry.lookup(task_registry, "task_tracker") do
      [{pid, _}] ->
        try do
          Process.exit(pid, :shutdown)
          # Give processes time to terminate gracefully
          Process.sleep(100)
        catch
          :error, _ -> :ok
        end

      _ ->
        :ok
    end

    # Terminate artifact registry and its processes
    Logger.debug("Terminating registry #{inspect(artifact_registry)}")

    case Registry.lookup(artifact_registry, "artifact_store") do
      [{pid, _}] ->
        try do
          Process.exit(pid, :shutdown)
          # Give processes time to terminate gracefully
          Process.sleep(100)
        catch
          :error, _ -> :ok
        end

      _ ->
        :ok
    end

    # Finally terminate the registries themselves
    cleanup_registry(task_registry)
    cleanup_registry(artifact_registry)
  end

  defp valid_objective_id?(id) when is_binary(id) do
    # Only allow alphanumeric characters and underscores
    String.match?(id, ~r/^[a-zA-Z0-9_]+$/)
  end

  defp valid_objective_id?(_), do: false
end
