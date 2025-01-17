defmodule Lux.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, [keys: :unique, name: Lux.Engine.Registry]},
      {Venomous.SnakeSupervisor, [strategy: :one_for_one, max_restarts: 0, max_children: 50]},
      {Venomous.PetSnakeSupervisor, [strategy: :one_for_one, max_children: 10]},
      {Lux.Specter.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Lux.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
