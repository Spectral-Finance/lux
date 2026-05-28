defmodule Lux.Analytics.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Lux.Analytics.Supervisor, []),
    ]

    opts = [strategy: :one_for_one, name: Lux.Analytics.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule Lux.Analytics.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      worker(Lux.Analytics.DeFiAnalytics, [])
    ]
    {:ok, children, strategy: :one_for_one}
  end
end