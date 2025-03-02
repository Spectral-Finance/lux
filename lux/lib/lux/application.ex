defmodule Lux.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Lux.Repo,
      {Venomous.SnakeSupervisor, [strategy: :one_for_one, max_restarts: 0, max_children: 50]},
      {Venomous.PetSnakeSupervisor, [strategy: :one_for_one, max_children: 10]},
      {Task.Supervisor, name: Lux.ScheduledTasksSupervisor},
      Lux.NodeJS,
      {Lux.Agent.Supervisor, []},
      Lux.AgentHub
    ]

    opts = [strategy: :one_for_one, name: Lux.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
