defmodule Lux.Monitoring.Supervisor do
  @moduledoc """
  Supervisor for the Smart Contract Event Monitoring System.
  Manages a dynamic set of EventWorkers.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # DynamicSupervisor for EventWorkers
      {DynamicSupervisor, name: Lux.Monitoring.WorkerSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  @doc """
  Starts a new monitor for a specific contract event.
  """
  def start_monitor(contract_address, event_signature, options \\ []) do
    spec = {Lux.Monitoring.Worker, {contract_address, event_signature, options}}
    DynamicSupervisor.start_child(Lux.Monitoring.WorkerSupervisor, spec)
  end
end
