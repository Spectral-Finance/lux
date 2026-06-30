defmodule Lux.AgentHub do
  @moduledoc """
  A central hub for managing and discovering agents in the system.
  Provides functionality for registering agents, tracking their status,
  and discovering agents based on capabilities.

  Multiple AgentHub instances can be started with different names:

      {:ok, pid} = AgentHub.start_link(name: :my_hub)
      {:ok, pid} = AgentHub.start_link(name: :another_hub)

  Then interact with specific hubs:

      AgentHub.register(hub, agent, pid, capabilities)
      AgentHub.find_by_capability(hub, :research)
  """

  use GenServer

  alias Lux.Agent

  require Logger

  @type agent_status :: :available | :busy | :offline
  @type agent_info :: %{
          agent: Agent.t(),
          pid: pid(),
          status: agent_status(),
          capabilities: [atom()],
          last_updated: DateTime.t()
        }

  @type hub :: atom() | pid()

  # Client API

  @doc """
  Starts a new AgentHub process.

  ## Options
    * `:name` - Registers the hub with the given name
  """
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    Logger.info("Starting AgentHub with name: #{inspect(name)}")
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Child spec for starting under a supervisor.

  ## Example:
      children = [
        {Lux.AgentHub, name: :my_hub}
      ]
      Supervisor.start_link(children, strategy: :one_for_one)
  """
  def child_spec(opts) do
    %{
      id: {__MODULE__, opts[:name] || :default},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Gets the default agent hub's pid.
  """
  @spec get_default() :: pid() | nil
  def get_default, do: Process.whereis(__MODULE__)

  @doc """
  Registers an agent in the hub.
  """
  @spec register(hub(), pid(), [atom()]) :: :ok | {:error, term()}
  def register(hub, agent, pid, capabilities \\ []) do
    Logger.debug(
      "Registering agent #{inspect(agent.id)} with capabilities #{inspect(capabilities)} in hub #{inspect(hub)}"
    )

    GenServer.call(hub, {:register, agent, pid, capabilities})
  end

  @doc """
  Updates the status of an agent.
  """
  @spec update_status(hub(), String.t(), agent_status()) :: :ok | {:error, term()}
  def update_status(hub, agent_id, status) when status in [:available, :busy, :offline] do
    Logger.debug(
      "Updating status for agent #{inspect(agent_id)} to #{inspect(status)} in hub #{inspect(hub)}"
    )

    GenServer.call(hub, {:update_status, agent_id, status})
  end

  @doc """
  Lists all registered agents.
  """
  @spec list_agents(hub()) :: [agent_info()]
  def list_agents(hub) do
    Logger.debug("Listing all agents in hub #{inspect(hub)}")
    GenServer.call(hub, :list_agents)
  end

  @doc """
  Finds agents by capability.
  """
  @spec find_by_capability(hub(), atom()) :: [agent_info()]
  def find_by_capability(hub, capability) do
    Logger.debug("Finding agents with capability #{inspect(capability)} in hub #{inspect(hub)}")
    GenServer.call(hub, {:find_by_capability, capability})
  end

  @doc """
  Gets information about a specific agent.
  """
  @spec get_agent_info(hub(), String.t()) :: {:ok, agent_info()} | {:error, :not_found}
  def get_agent_info(hub, agent_id) do
    Logger.debug("Getting info for agent #{inspect(agent_id)} from hub #{inspect(hub)}")
    GenServer.call(hub, {:get_agent_info, agent_id})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    Logger.info("Initializing AgentHub with options: #{inspect(opts)}")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, agent, pid, capabilities}, _from, state) do
    Logger.debug("Hub handling register request for agent: #{inspect(agent.id)}")

    agent_info = %{
      agent: agent,
      pid: pid,
      status: :available,
      capabilities: capabilities,
      last_updated: DateTime.utc_now()
    }

    # Monitor the agent's process to track when it goes down
    Process.monitor(pid)

    Logger.debug("Agent registered successfully with info: #{inspect(agent_info)}")
    {:reply, :ok, Map.put(state, agent.id, agent_info)}
  end

  @impl true
  def handle_call({:update_status, agent_id, status}, _from, state) do
    Logger.debug(
      "Hub handling status update for agent #{inspect(agent_id)} to #{inspect(status)}"
    )

    case Map.get(state, agent_id) do
      nil ->
        Logger.warning("Attempted to update status for unknown agent: #{inspect(agent_id)}")
        {:reply, {:error, :not_found}, state}

      agent_info ->
        updated_info = %{
          agent_info
          | status: status,
            last_updated: DateTime.utc_now()
        }

        Logger.debug("Agent status updated successfully: #{inspect(updated_info)}")
        {:reply, :ok, Map.put(state, agent_id, updated_info)}
    end
  end

  @impl true
  def handle_call(:list_agents, _from, state) do
    Logger.debug("Hub handling list_agents request, found #{map_size(state)} agents")
    {:reply, Map.values(state), state}
  end

  @impl true
  def handle_call({:find_by_capability, capability}, _from, state) do
    Logger.debug("Hub searching for agents with capability: #{inspect(capability)}")

    agents =
      state
      |> Map.values()
      |> Enum.filter(fn %{capabilities: caps} -> capability in caps end)

    Logger.debug("Found #{length(agents)} agents with capability #{inspect(capability)}")
    {:reply, agents, state}
  end

  @impl true
  def handle_call({:get_agent_info, agent_id}, _from, state) do
    Logger.debug("Hub handling get_agent_info request for agent: #{inspect(agent_id)}")

    case Map.get(state, agent_id) do
      nil ->
        Logger.warning("Attempted to get info for unknown agent: #{inspect(agent_id)}")
        {:reply, {:error, :not_found}, state}

      info ->
        Logger.debug("Found agent info: #{inspect(info)}")
        {:reply, {:ok, info}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    Logger.debug(
      "Received DOWN message for process #{inspect(pid)} with reason: #{inspect(reason)}"
    )

    # Find and mark the agent as offline when its process goes down
    case Enum.find(state, fn {_, info} -> info.pid == pid end) do
      {agent_id, agent_info} ->
        Logger.debug("Marking agent #{inspect(agent_id)} as offline")

        updated_state =
          Map.put(state, agent_id, %{
            agent_info
            | status: :offline,
              last_updated: DateTime.utc_now()
          })

        {:noreply, updated_state}

      nil ->
        Logger.debug("No agent found for DOWN process #{inspect(pid)}")
        {:noreply, state}
    end
  end
end
