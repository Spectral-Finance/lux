defmodule Lux.Agent.Directory do
  @moduledoc """
  Directory for managing and discovering agents in the system.
  Provides functionality for registering agents, tracking their status,
  and discovering agents based on capabilities.
  """

  use GenServer

  alias Lux.Agent

  @type agent_status :: :available | :busy | :offline
  @type agent_info :: %{
          agent: Agent.t(),
          pid: pid(),
          status: agent_status(),
          capabilities: [atom()],
          last_updated: DateTime.t()
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers an agent in the directory.
  """
  @spec register(Agent.t(), pid(), [atom()]) :: :ok | {:error, term()}
  def register(agent, pid, capabilities \\ []) do
    GenServer.call(__MODULE__, {:register, agent, pid, capabilities})
  end

  @doc """
  Updates the status of an agent.
  """
  @spec update_status(String.t(), agent_status()) :: :ok | {:error, term()}
  def update_status(agent_id, status) when status in [:available, :busy, :offline] do
    GenServer.call(__MODULE__, {:update_status, agent_id, status})
  end

  @doc """
  Lists all registered agents.
  """
  @spec list_agents() :: [agent_info()]
  def list_agents do
    GenServer.call(__MODULE__, :list_agents)
  end

  @doc """
  Finds agents by capability.
  """
  @spec find_by_capability(atom()) :: [agent_info()]
  def find_by_capability(capability) do
    GenServer.call(__MODULE__, {:find_by_capability, capability})
  end

  @doc """
  Gets information about a specific agent.
  """
  @spec get_agent_info(String.t()) :: {:ok, agent_info()} | {:error, :not_found}
  def get_agent_info(agent_id) do
    GenServer.call(__MODULE__, {:get_agent_info, agent_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Directory state: %{agent_id => agent_info()}
    {:ok, %{}}
  end

  @impl true
  def handle_call({:register, agent, pid, capabilities}, _from, state) do
    agent_info = %{
      agent: agent,
      pid: pid,
      status: :available,
      capabilities: capabilities,
      last_updated: DateTime.utc_now()
    }

    # Monitor the agent's process to track when it goes down
    Process.monitor(pid)

    {:reply, :ok, Map.put(state, agent.id, agent_info)}
  end

  @impl true
  def handle_call({:update_status, agent_id, status}, _from, state) do
    case Map.get(state, agent_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      agent_info ->
        updated_info = %{
          agent_info
          | status: status,
            last_updated: DateTime.utc_now()
        }

        {:reply, :ok, Map.put(state, agent_id, updated_info)}
    end
  end

  @impl true
  def handle_call(:list_agents, _from, state) do
    {:reply, Map.values(state), state}
  end

  @impl true
  def handle_call({:find_by_capability, capability}, _from, state) do
    agents =
      state
      |> Map.values()
      |> Enum.filter(fn %{capabilities: caps} -> capability in caps end)

    {:reply, agents, state}
  end

  @impl true
  def handle_call({:get_agent_info, agent_id}, _from, state) do
    case Map.get(state, agent_id) do
      nil -> {:reply, {:error, :not_found}, state}
      info -> {:reply, {:ok, info}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Find and mark the agent as offline when its process goes down
    case Enum.find(state, fn {_, info} -> info.pid == pid end) do
      {agent_id, _} ->
        updated_info =
          update_in(state[agent_id], fn info ->
            %{info | status: :offline, last_updated: DateTime.utc_now()}
          end)

        {:noreply, updated_info}

      nil ->
        {:noreply, state}
    end
  end
end
