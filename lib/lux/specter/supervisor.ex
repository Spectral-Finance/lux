defmodule Lux.Specter.Supervisor do
  @moduledoc """
  Supervisor for managing Specter processes.
  Handles starting, stopping, and monitoring specters.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new specter process.
  """
  def start_specter(%Lux.Specter{} = specter) do
    child_spec = {Lux.Specter.Runner, specter}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops a specter process.
  """
  def stop_specter(specter_id) do
    case find_specter(specter_id) do
      {:ok, pid} -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      error -> error
    end
  end

  @doc """
  Lists all running specters.
  """
  def list_specters do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)
    |> Enum.map(&Lux.Specter.Runner.get_specter/1)
  end

  @doc """
  Finds a specter process by its ID.
  """
  def find_specter(specter_id) do
    case list_specters() do
      specters when is_list(specters) ->
        Enum.find_value(specters, {:error, :not_found}, fn
          {:ok, %Lux.Specter{id: ^specter_id} = _specter, pid} -> {:ok, pid}
          _ -> nil
        end)
    end
  end
end
