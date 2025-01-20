defmodule Lux.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Lux.Registry},
      {Venomous.SnakeSupervisor, [strategy: :one_for_one, max_restarts: 0, max_children: 50]},
      {Venomous.PetSnakeSupervisor, [strategy: :one_for_one, max_children: 10]}
    ]

    extra_children =
      if Application.get_env(:lux, :config_env) == :test do
        []
      else
        [
          {Lux.Engine.SignalsQueue.BasicQueueImpl, []}
        ]
      end

    opts = [strategy: :one_for_one, name: Lux.Supervisor]
    Supervisor.start_link(children ++ extra_children, opts)
  end

  if Mix.env() == :dev do
    def observer do
      Mix.ensure_application!(:wx)
      Mix.ensure_application!(:runtime_tools)
      Mix.ensure_application!(:observer)

      :observer.start()
    end
  end
end
