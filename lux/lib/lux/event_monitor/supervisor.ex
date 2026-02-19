defmodule Lux.EventMonitor.Supervisor do
  @moduledoc """
  Supervisor for the event monitoring system.

  Starts and manages the event store, webhook manager, and the main
  event monitor GenServer.
  """

  use Supervisor

  @doc """
  Starts the event monitor supervisor.

  ## Options

    * `:name` - Supervisor name (default: `__MODULE__`)
    * `:store_opts` - Options passed to `Lux.EventMonitor.Store`
    * `:webhook_opts` - Options passed to `Lux.EventMonitor.Webhook`
    * `:monitor_opts` - Options passed to `Lux.EventMonitor`
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    store_opts = Keyword.get(opts, :store_opts, [])
    webhook_opts = Keyword.get(opts, :webhook_opts, [])
    monitor_opts = Keyword.get(opts, :monitor_opts, [])

    children = [
      {Lux.EventMonitor.Store, Keyword.put_new(store_opts, :name, Lux.EventMonitor.Store)},
      {Lux.EventMonitor.Webhook, Keyword.put_new(webhook_opts, :name, Lux.EventMonitor.Webhook)},
      {Lux.EventMonitor, Keyword.put_new(monitor_opts, :name, Lux.EventMonitor)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
