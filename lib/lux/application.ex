defmodule Lux.Application do
  @moduledoc false
  use Application

  @config_env Application.compile_env(:lux, :config_env)

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

  if @config_env == :dev do
    IO.inspect("OMGOMGOMGOMG")

    def oberver do
      Mix.ensure_application!(:wx)
      Mix.ensure_application!(:runtime_tools)
      Mix.ensure_application!(:observer)

      :observer.start()
    end
  end
end
