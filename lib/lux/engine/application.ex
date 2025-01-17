defmodule Lux.Engine.Application do
  @moduledoc """
  Manages all core components including queues and routers.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Lux.Engine.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Lux.Engine.QueueSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Lux.Engine.RouterSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Lux.Engine.DeliverySupervisor}
    ]

    opts = [strategy: :one_for_one, name: Lux.Engine.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
