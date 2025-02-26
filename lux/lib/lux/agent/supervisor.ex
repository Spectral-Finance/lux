defmodule Lux.Agent.Supervisor do
  @moduledoc """
  Supervisor for managing Agent processes.
  Handles starting, stopping, and monitoring agents.
  """

  use DynamicSupervisor

  alias Lux.Agent.Runner

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new agent process.
  """
  def start_agent(%Lux.Agent{} = agent) do
    child_spec = {Runner, agent}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops a agent process.
  """
  def stop_agent(agent_id) do
    case find_agent(agent_id) do
      {:ok, pid} -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      error -> error
    end
  end

  @doc """
  Lists all running agents.
  """
  def list_agents do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)

    # |> Enum.map(&Runner.get_agent/1)
  end

  @doc """
  Finds a agent process by its ID.
  """
  def find_agent(agent_id) do
    case list_agents() do
      agents when is_list(agents) ->
        Enum.find_value(agents, {:error, :not_found}, fn
          {:ok, %Lux.Agent{id: ^agent_id} = _agent, pid} -> {:ok, pid}
          _ -> nil
        end)
    end
  end
end
