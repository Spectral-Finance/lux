defmodule Lux.Company do
  @moduledoc """
  Defines the core company functionality and structure.
  A company is the highest-level organizational unit that coordinates agent-based workflows.
  """

  use GenServer

  alias Lux.Company.Roles
  alias Lux.Schemas.Companies.ObjectiveSignal
  alias Lux.Signal.Router

  require Logger

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          mission: String.t(),
          module: module(),
          ceo: map(),
          roles: [map()],
          objectives: [Lux.Company.Objective.t()],
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    :mission,
    :module,
    :ceo,
    :signal_router,
    :agent_hub,
    roles: [],
    objectives: [],
    metadata: %{}
  ]

  @doc """
  Starts a company with the given configuration.
  """
  def start_link(module, opts \\ []) do
    GenServer.start_link(__MODULE__, {module, opts})
  end

  @doc """
  Lists all roles in the company.
  """
  def list_roles(company) do
    GenServer.call(company, :list_roles)
  end

  @doc """
  Gets a specific role by ID.
  """
  def get_role(company, role_id) do
    GenServer.call(company, {:get_role, role_id})
  end

  @doc """
  Assigns an agent to a role.
  """
  def assign_agent(company, role_id, agent) do
    GenServer.call(company, {:assign_agent, role_id, agent})
  end

  @doc """
  Lists all objectives in the company.
  """
  def list_objectives(company) do
    GenServer.call(company, :list_objectives)
  end

  @doc """
  Gets a specific objective by ID.
  """
  def get_objective(company, objective_id) do
    GenServer.call(company, {:get_objective, objective_id})
  end

  @doc """
  Gets the status of an objective.
  """
  def get_objective_status(company, objective_id) do
    GenServer.call(company, {:get_objective_status, objective_id})
  end

  @doc """
  Gets the artifacts produced by an objective.
  """
  def get_objective_artifacts(company, objective_id) do
    GenServer.call(company, {:get_objective_artifacts, objective_id})
  end

  @doc """
  Assigns an agent to an objective.
  """
  def assign_agent_to_objective(company, objective_id, agent_id) do
    GenServer.call(company, {:assign_agent_to_objective, objective_id, agent_id})
  end

  @doc """
  Starts an objective.
  """
  def start_objective(company, objective_id) do
    GenServer.call(company, {:start_objective, objective_id})
  end

  @doc """
  Updates the progress of an objective.
  """
  def update_objective_progress(company, objective_id, progress) do
    GenServer.call(company, {:update_objective_progress, objective_id, progress})
  end

  @doc """
  Completes an objective.
  """
  def complete_objective(company, objective_id) do
    GenServer.call(company, {:complete_objective, objective_id})
  end

  @doc """
  Marks an objective as failed.
  """
  def fail_objective(company, objective_id, reason \\ nil) do
    GenServer.call(company, {:fail_objective, objective_id, reason})
  end

  @doc """
  Runs a company with the given configuration.
  This starts all necessary processes and initializes the company state.

  ## Options
  - `:router` - The signal router to use for agent communication (required)
  - `:hub` - The agent hub to use for agent management (required)
  - `:timeout` - Timeout for agent initialization (default: 30_000)
  """
  def run(company, opts \\ []) do
    router = Keyword.fetch!(opts, :router)
    hub = Keyword.fetch!(opts, :hub)
    timeout = Keyword.get(opts, :timeout, 30_000)

    with {:ok, _} <- validate_company(company),
         {:ok, _} <- validate_router(router),
         {:ok, _} <- validate_hub(hub) do
      # Start the company
      {:ok, pid} = start_link(company, opts)

      # Initialize roles and agents
      {:ok, _} = init_roles(pid, timeout)
      {:ok, _} = init_agents(pid, timeout)

      {:ok, pid}
    end
  end

  @doc """
  Runs an objective in the company.
  """
  def run_objective(company, objective_id, input \\ %{}) do
    GenServer.call(company, {:run_objective, objective_id, input})
  end

  # Server Callbacks

  @impl true
  def init({module, opts}) do
    require Logger

    Logger.debug("Initializing company with module: #{inspect(module)}")

    # Get company configuration
    company_config = module.__company__()
    Logger.debug("Company config during init: #{inspect(company_config)}")

    Logger.info("Starting company: #{company_config.name}")
    Logger.info("Mission: #{company_config.mission}")
    Logger.info("\nCEO:")

    # Initialize CEO
    ceo = company_config.ceo
    Logger.info("  - #{ceo.name} with capabilities: #{Enum.join(ceo.capabilities, ", ")}")
    Logger.info("  - Using agent: #{ceo.agent}")

    # Initialize members
    Logger.info("\nMembers:")

    members = company_config.roles

    Enum.each(members, fn member ->
      Logger.info("  - #{member.name} with capabilities: #{Enum.join(member.capabilities, ", ")}")
      Logger.info("    Using agent: #{member.agent}")
    end)

    # Store signal router and agent hub if provided
    signal_router = Keyword.get(opts, :signal_router)
    agent_hub = Keyword.get(opts, :agent_hub)

    {:ok,
     %{
       module: module,
       opts: opts,
       signal_router: signal_router,
       agent_hub: agent_hub,
       roles: %{},
       objectives: Enum.map(company_config.objectives, fn obj ->
        {obj.id, obj}
      end) |> Enum.into(%{}),
       artifacts: %{}
     }} |> dbg()
  end

  @impl true
  def handle_call(:list_roles, _from, state) do
    {:reply, {:ok, Map.values(state.roles)}, state}
  end

  def handle_call({:get_role, role_id}, _from, state) do
    case Map.get(state.roles, role_id) do
      nil -> {:reply, {:error, :not_found}, state}
      role -> {:reply, {:ok, role}, state}
    end
  end

  def handle_call({:assign_agent, role_id, agent}, _from, state) do
    case Map.get(state.roles, role_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      role ->
        updated_role = %{role | agent: agent}
        updated_roles = Map.put(state.roles, role_id, updated_role)
        {:reply, {:ok, updated_role}, %{state | roles: updated_roles}}
    end
  end

  def handle_call(:list_objectives, _from, state) do
    {:reply, {:ok, Map.values(state.objectives)}, state}
  end

  def handle_call({:get_objective, objective_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil -> {:reply, {:error, :not_found}, state}
      objective -> {:reply, {:ok, objective}, state}
    end
  end

  def handle_call({:get_objective_status, objective_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil -> {:reply, {:error, :not_found}, state}
      objective -> {:reply, {:ok, objective.status}, state}
    end
  end

  def handle_call({:get_objective_artifacts, objective_id}, _from, state) do
    case Map.get(state.artifacts, objective_id) do
      nil -> {:reply, {:error, :not_found}, state}
      artifacts -> {:reply, {:ok, artifacts}, state}
    end
  end

  def handle_call({:assign_agent_to_objective, objective_id, agent_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective = %{objective | assigned_agent: agent_id}
        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:start_objective, objective_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective = %{objective | status: :in_progress, started_at: DateTime.utc_now()}
        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:update_objective_progress, objective_id, progress}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        Logger.debug("Objective not found: #{objective_id}")
        {:reply, {:error, :not_found}, state}

      objective ->
        Logger.debug(
          "Updating objective progress: #{objective_id} from #{objective.progress} to #{progress}"
        )

        updated_objective = %{objective | progress: progress}
        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:complete_objective, objective_id}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective = %{
          objective
          | status: :completed,
            completed_at: DateTime.utc_now(),
            progress: 100
        }

        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:fail_objective, objective_id, reason}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective = %{
          objective
          | status: :failed,
            completed_at: DateTime.utc_now(),
            error: reason
        }

        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        {:reply, {:ok, updated_objective}, %{state | objectives: updated_objectives}}
    end
  end

  def handle_call({:run_objective, objective_id, input}, _from, state) do
    case start_objective_execution(objective_id, input, state) do
      {:ok, updated_objective, new_state} ->
        {:reply, {:ok, updated_objective}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @doc """
  Updates the status of an objective. This is called by the objective process, not internally.
  """
  def handle_call({:update_objective_status, objective_id, status, progress}, _from, state) do
    case Map.get(state.objectives, objective_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      objective ->
        updated_objective =
          Map.merge(objective, %{
            status: status,
            progress: progress
          })

        updated_objectives = Map.put(state.objectives, objective_id, updated_objective)
        new_state = %{state | objectives: updated_objectives}

        # Create status update signal for CEO
        signal = %Lux.Signal{
          id: Lux.UUID.generate(),
          schema_id: ObjectiveSignal,
          payload: %{
            "type" => "status_update",
            "objective_id" => objective_id,
            "title" => to_string(objective.name),
            "status" => to_string(status),
            "progress" => progress
          },
          recipient: state.module.ceo().id,
          sender: objective_id
        }

        # Route the signal through the router if configured
        if state.signal_router && state.agent_hub do
          :ok =
            Router.route(signal,
              router: state.signal_router,
              hub: state.agent_hub
            )
        end

        {:reply, {:ok, updated_objective}, new_state}
    end
  end

  # Private Functions

  defp validate_company(company) do
    require Logger

    Logger.debug("Validating company module: #{inspect(company)}")

    # Try to get company config
    if :erlang.function_exported(company, :__company__, 0) do
      config = company.__company__()
      Logger.debug("Company config: #{inspect(config)}")

      cond do
        is_nil(config.name) ->
          Logger.error("Company name is missing")
          {:error, :missing_name}

        is_nil(config.mission) ->
          Logger.error("Company mission is missing")
          {:error, :missing_mission}

        is_nil(config.ceo) ->
          Logger.error("Company CEO is missing")
          {:error, :missing_ceo}

        true ->
          {:ok, company}
      end
    else
      Logger.error("Company module does not implement __company__/0")
      {:error, :invalid_company}
    end
  end

  defp validate_router(router) do
    if function_exported?(router, :start_link, 1) do
      {:ok, router}
    else
      {:error, :invalid_router}
    end
  end

  defp validate_hub(hub) do
    if function_exported?(hub, :start_link, 1) do
      {:ok, hub}
    else
      {:error, :invalid_hub}
    end
  end

  defp validate_objective_input(objective, input, _state) do
    # Get the input schema from the objective
    case objective.input_schema do
      %{required: required_fields} = schema ->
        # First validate required fields
        missing_fields = Enum.reject(required_fields, &Map.has_key?(input, &1))

        if Enum.empty?(missing_fields) do
          # Then validate field types if specified
          # credo:disable-for-next-line
          case validate_field_types(input, schema) do
            :ok -> {:ok, objective}
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, {:missing_required_fields, missing_fields}}
        end

      nil ->
        {:error, :missing_input_schema}
    end
  end

  defp validate_field_types(input, %{properties: properties}) do
    Enum.reduce_while(input, :ok, fn {field, value}, _acc ->
      case Map.get(properties, field) do
        %{type: type} ->
          # credo:disable-for-next-line
          if validate_type(value, type) do
            {:cont, :ok}
          else
            {:halt, {:error, {:invalid_type, field, type, value}}}
          end

        _ ->
          # Field not in schema, assume valid
          {:cont, :ok}
      end
    end)
  end

  defp validate_field_types(_input, _schema), do: :ok

  defp validate_type(value, "string") when is_binary(value), do: true
  defp validate_type(value, "number") when is_number(value), do: true
  defp validate_type(value, "integer") when is_integer(value), do: true
  defp validate_type(value, "boolean") when is_boolean(value), do: true
  defp validate_type(value, "array") when is_list(value), do: true
  defp validate_type(value, "object") when is_map(value), do: true
  defp validate_type(_, _), do: false

  defp init_roles(pid, _timeout) do
    # Initialize roles from the company module
    module = :sys.get_state(pid).module
    ceo = module.ceo()
    members = module.members()

    # Create the CEO role
    {:ok, _} =
      Roles.create(pid, %{
        id: Lux.UUID.generate(),
        name: ceo.name,
        type: :ceo,
        capabilities: ceo.capabilities,
        agent: ceo.agent
      })

    # Create member roles
    Enum.each(members, fn member ->
      {:ok, _} =
        Roles.create(pid, %{
          id: Lux.UUID.generate(),
          name: member.name,
          type: :member,
          capabilities: member.capabilities,
          agent: member.agent
        })
    end)

    {:ok, pid}
  end

  defp init_agents(pid, _timeout) do
    # Start agents for each role
    {:ok, roles} = list_roles(pid)

    Enum.each(roles, fn role ->
      {:ok, _} = assign_agent(pid, role.id, role.agent)
    end)

    {:ok, pid}
  end

  # credo:disable-for-next-line
  defp start_objective_execution(objective_id, input, state) do
    Logger.debug("Starting objective execution: #{objective_id}")
    Logger.debug("Input: #{inspect(input)}")

    case Map.get(state.objectives, objective_id) do
      nil ->
        {:error, :not_found}

      objective ->
        # Validate input against objective schema
        case validate_objective_input(objective, input, state) do
          {:ok, _} ->
            # Start the execution engine supervisor for this objective
            supervisor_name = Module.concat(objective_id, ExecutionSupervisor)

            case Lux.Company.ExecutionEngine.Supervisor.start_link(name: supervisor_name) do
              {:ok, _pid} ->
                # Start the objective process
                case Lux.Company.ExecutionEngine.Supervisor.start_objective(
                       supervisor_name,
                       objective,
                       self(),
                       input,
                       objective_id
                     ) do
                  {:ok, _pid} ->
                    # Create initial signal for CEO evaluation
                    signal = %Lux.Signal{
                      id: Lux.UUID.generate(),
                      schema_id: ObjectiveSignal,
                      payload: %{
                        "type" => "evaluate",
                        "objective_id" => objective_id,
                        "title" => to_string(objective.name),
                        "input" => input
                      },
                      recipient: state.module.ceo().id,
                      sender: objective_id
                    }

                    # Route the signal through the router if configured
                    # credo:disable-for-next-line
                    if state.signal_router && state.agent_hub do
                      :ok =
                        Router.route(signal,
                          router: state.signal_router,
                          hub: state.agent_hub
                        )
                    end

                    # Update objective status
                    updated_objective = %{
                      objective
                      | status: :in_progress,
                        started_at: DateTime.utc_now()
                    }

                    updated_objectives =
                      Map.put(state.objectives, objective_id, updated_objective)

                    new_state = %{state | objectives: updated_objectives}

                    {:ok, updated_objective, new_state}

                  error ->
                    Logger.error("Failed to start objective process: #{inspect(error)}")
                    {:error, :start_failed}
                end

              error ->
                Logger.error("Failed to start execution supervisor: #{inspect(error)}")
                {:error, :supervisor_failed}
            end

          error ->
            error
        end
    end
  end

  defmacro __using__(_opts) do
    quote do
      use Lux.Company.DSL
    end
  end
end
