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
      Lux.AgentHub
    ] ++ optional_children()

    opts = [strategy: :one_for_one, name: Lux.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp optional_children do
    if Application.get_env(:lux, :env) == :test do
      # the LLM provider layer is started per-test by its unit tests
      [RateLimiter]
    else
      [
        Lux.LLM.Registry,
        Lux.LLM.Cost,
        Lux.LLM.Stats,
        Lux.LLM.CircuitBreaker,
        # register providers configured under config :lux, Lux.LLM.Gateway, :register
        {Task, fn -> Lux.LLM.Gateway.register_configured_providers() end}
      ]
    end
  end
end
