defmodule Lux.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Venomous.SnakeSupervisor, [strategy: :one_for_one, max_restarts: 0, max_children: 50]},
      {Venomous.PetSnakeSupervisor, [strategy: :one_for_one, max_children: 10]},
      {Task.Supervisor, name: Lux.ScheduledTasksSupervisor},
      Lux.NodeJS,
      {Lux.Agent.Supervisor, []},
      Lux.AgentHub,
      # LLM Provider Registry and Monitoring
      Supervisor.child_spec({Task, fn -> Lux.LLM.Registry.start_link() end}, id: :llm_registry),
      Supervisor.child_spec({Task, fn -> Lux.LLM.Monitoring.start_link() end}, id: :llm_monitoring)
    ] ++ optional_children()

    opts = [strategy: :one_for_one, name: Lux.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp optional_children do
    if Application.get_env(:lux, :env) == :test do
      [RateLimiter]
    else
      []
    end
  end
end
