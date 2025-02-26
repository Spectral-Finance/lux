defmodule Lux.Signal.Router do
  @moduledoc """
  Defines the router behavior and provides a clean interface for signal routing.

  The router is responsible for delivering signals between agents and managing
  subscriptions to signal events. It supports different implementations (e.g. Local, Remote)
  through a behavior pattern.

  ## Usage

      # Start a local router
      {:ok, _pid} = Router.Local.start_link(name: :my_router)

      # Route a signal
      Router.route(signal, implementation: Router.Local, name: :my_router, hub: :my_hub)

      # Subscribe to signal events
      Router.subscribe(signal_id, implementation: Router.Local, name: :my_router)
  """

  alias Lux.Signal.Router.Local

  @type router :: GenServer.server()
  @type signal :: Lux.Signal.t()
  @type router_opts :: keyword()

  @doc """
  Routes a signal through the router.

  ## Options
    * `:implementation` - The router implementation module (defaults to Local)
    * `:name` - The registered name of the router process
    * `:hub` - The hub to use for routing (required)
  """
  @callback route(signal(), router_opts()) :: :ok | {:error, term()}

  @doc """
  Subscribes to signal events.

  ## Options
    * `:implementation` - The router implementation module (defaults to Local)
    * `:name` - The registered name of the router process
  """
  @callback subscribe(String.t(), router_opts()) :: :ok | {:error, term()}

  @doc """
  Unsubscribes from signal events.

  ## Options
    * `:implementation` - The router implementation module (defaults to Local)
    * `:name` - The registered name of the router process
  """
  @callback unsubscribe(String.t(), router_opts()) :: :ok | {:error, term()}

  @doc """
  Routes a signal through the router.

  ## Options
    * `:implementation` - The router implementation module (defaults to Local)
    * `:name` - The registered name of the router process
    * `:hub` - The hub to use for routing (required)
  """
  def route(signal, opts) do
    get_impl(opts).route(signal, opts)
  end

  @doc """
  Subscribes to signal events.

  ## Options
    * `:implementation` - The router implementation module (defaults to Local)
    * `:name` - The registered name of the router process
  """
  def subscribe(signal_id, opts) do
    get_impl(opts).subscribe(signal_id, opts)
  end

  @doc """
  Unsubscribes from signal events.

  ## Options
    * `:implementation` - The router implementation module (defaults to Local)
    * `:name` - The registered name of the router process
  """
  def unsubscribe(signal_id, opts) do
    get_impl(opts).unsubscribe(signal_id, opts)
  end

  defp get_impl(opts), do: Keyword.get(opts, :implementation, Local)
end
