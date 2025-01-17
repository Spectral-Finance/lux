defmodule Lux.Engine.Application do
  @moduledoc """
  Manages all core components including queues and routers.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Registry, keys: :unique, name: Lux.Engine.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Lux.Engine.QueueSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Lux.Engine.RouterSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Lux.Engine.DeliverySupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
