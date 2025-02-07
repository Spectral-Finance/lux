defmodule Lux.Signal.Router do
  @moduledoc """
  Defines the behaviour for signal routing between agents.

  Routers are responsible for:
  - Validating signals before delivery
  - Finding appropriate target agents
  - Delivering signals to target agents
  - Supporting subscriptions to signal delivery events

  Different implementations can handle routing in various ways:
  - Local routing between agents in the same BEAM VM
  - Remote routing to agents in different nodes
  - External routing to agents in different systems/providers
  """

  @type router :: module() | {module(), term()}
  @type routing_options :: keyword()

  @doc """
  Starts a router process.
  """
  @callback start_link(opts :: keyword()) :: GenServer.on_start()

  @doc """
  Routes a signal to its target agent.
  Returns :ok if the signal was accepted for routing.
  """
  @callback route(signal :: Lux.Signal.t(), opts :: routing_options()) ::
              :ok | {:error, term()}

  @doc """
  Subscribes to future signal delivery events.
  Subscribers will receive messages in the format:
  {:signal_delivered, signal_id} | {:signal_failed, signal_id, reason}
  """
  @callback subscribe(signal_id :: String.t(), opts :: routing_options()) ::
              :ok | {:error, term()}

  @doc """
  Unsubscribes from signal delivery events.
  """
  @callback unsubscribe(signal_id :: String.t(), opts :: routing_options()) ::
              :ok | {:error, term()}

  # Convenience functions that delegate to the configured router
  def route(signal, opts \\ []) do
    {router, router_opts} = get_router(opts)
    router.route(signal, router_opts)
  end

  def subscribe(signal_id, opts \\ []) do
    {router, router_opts} = get_router(opts)
    router.subscribe(signal_id, router_opts)
  end

  def unsubscribe(signal_id, opts \\ []) do
    {router, router_opts} = get_router(opts)
    router.unsubscribe(signal_id, router_opts)
  end

  # Private Helpers

  defp get_router(opts) do
    case Keyword.get(opts, :router, Lux.Signal.Router.Local) do
      {router, router_opts} -> {router, router_opts}
      router when is_atom(router) -> {router, []}
    end
  end
end
