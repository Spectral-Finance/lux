defmodule Lux.Signal.Router.Local do
  @moduledoc """
  Local implementation of the Router behaviour using GenServer.

  This router handles signal delivery between agents running in the same BEAM VM.
  It supports simple pub/sub for signal delivery events.
  """

  @behaviour Lux.Signal.Router

  use GenServer

  alias Lux.AgentHub
  alias Lux.Signal
  alias Lux.Signal.Router

  require Logger

  # Client API

  @doc """
  Starts the local router with the given options.
  """
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    Logger.info("Starting Local Router with name: #{inspect(name)}")
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl Router
  def route(signal, opts \\ []) do
    hub = Keyword.fetch!(opts, :hub)
    router_name = get_name(opts)
    Logger.debug("Routing signal through router #{inspect(router_name)} to hub #{inspect(hub)}")
    Logger.debug("Signal: #{inspect(signal, pretty: true)}")
    GenServer.call(router_name, {:route, signal, hub})
  end

  @impl Router
  def subscribe(signal_id, opts \\ []) do
    router_name = get_name(opts)
    Logger.debug("Subscribing to signal #{signal_id} on router #{inspect(router_name)}")
    GenServer.call(router_name, {:subscribe, signal_id, self()})
  end

  @impl Router
  def unsubscribe(signal_id, opts \\ []) do
    router_name = get_name(opts)
    Logger.debug("Unsubscribing from signal #{signal_id} on router #{inspect(router_name)}")
    GenServer.call(router_name, {:unsubscribe, signal_id, self()})
  end

  @doc """
  Lists all agents registered with the router.
  """
  def list_agents(opts \\ []) do
    router_name = get_name(opts)
    GenServer.call(router_name, :list_agents)
  end

  # Server Callbacks

  @impl GenServer
  def init(opts) do
    Logger.info("Initializing Local Router with options: #{inspect(opts)}")

    {:ok,
     %{
       # signal_id => MapSet of subscriber pids
       subscribers: %{},
       opts: opts
     }}
  end

  @impl GenServer
  def handle_call({:route, signal, hub}, _from, state) do
    Logger.debug("Router handling route request for signal: #{inspect(signal.id)}")

    with {:ok, signal} <- validate_signal(signal),
         {:ok, targets} <- find_targets(signal, hub) do
      router_name = state.opts[:name] || __MODULE__

      # Deliver synchronously to ensure notifications are sent
      delivery_results = deliver_to_targets(signal, targets, router_name)
      Logger.debug("Signal delivery results: #{inspect(delivery_results)}")

      {:reply, :ok, state}
    else
      error ->
        Logger.error("Router failed to route signal: #{inspect(error)}")
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, signal_id, subscriber}, _from, state) do
    Logger.debug(
      "Router handling subscribe request for signal #{signal_id} from #{inspect(subscriber)}"
    )

    subscribers = Map.get(state.subscribers, signal_id, MapSet.new())
    new_subscribers = MapSet.put(subscribers, subscriber)
    {:reply, :ok, put_in(state.subscribers[signal_id], new_subscribers)}
  end

  @impl GenServer
  def handle_call({:unsubscribe, signal_id, subscriber}, _from, state) do
    Logger.debug(
      "Router handling unsubscribe request for signal #{signal_id} from #{inspect(subscriber)}"
    )

    subscribers = Map.get(state.subscribers, signal_id, MapSet.new())
    new_subscribers = MapSet.delete(subscribers, subscriber)

    new_state =
      if MapSet.size(new_subscribers) == 0 do
        Map.update!(state, :subscribers, &Map.delete(&1, signal_id))
      else
        put_in(state.subscribers[signal_id], new_subscribers)
      end

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:list_agents, _from, state) do
    {:reply, :ok, state}
  end

  # Private Functions

  defp get_name(opts) do
    Keyword.get(opts, :router, Keyword.get(opts, :name, __MODULE__))
  end

  defp validate_signal(%Signal{id: id} = signal) when not is_nil(id) do
    {:ok, signal}
  end

  defp validate_signal(_), do: {:error, :invalid_signal}

  defp find_targets(%Signal{recipient: recipient}, hub) when not is_nil(recipient) do
    case AgentHub.get_agent_info(hub, recipient) do
      {:ok, info} -> {:ok, [info]}
      error -> error
    end
  end

  defp find_targets(_, _), do: {:error, :invalid_target}

  defp deliver_to_targets(signal, targets, router_name) do
    router_pid = Process.whereis(router_name)

    # First deliver all signals
    delivery_results =
      Enum.map(targets, fn target ->
        try do
          # Check if target process exists
          if Process.alive?(target.pid) do
            # Send signal to target and wait for it to be delivered
            case Process.send(target.pid, {:signal, signal}, [:noconnect]) do
              :ok ->
                # Only send signal and delivery notifications on success
                if router_pid do
                  send(router_pid, {:notify_subscribers, {:signal, signal}})
                  send(router_pid, {:notify_subscribers, {:signal_delivered, signal.id}})
                end

                {:ok, target}

              error ->
                # Send failure notification on send error
                if router_pid do
                  send(router_pid, {:notify_subscribers, {:signal_failed, signal.id, error}})
                end

                {:error, target, error}
            end
          else
            # Process is dead, send failure notification
            if router_pid do
              send(
                router_pid,
                {:notify_subscribers, {:signal_failed, signal.id, :process_not_alive}}
              )
            end

            {:error, target, :process_not_alive}
          end
        catch
          kind, reason ->
            Logger.error(
              "Failed to deliver signal #{signal.id} to agent #{target.agent.id}: #{inspect({kind, reason})}"
            )

            if router_pid do
              send(router_pid, {:notify_subscribers, {:signal_failed, signal.id, reason}})
            end

            {:error, target, reason}
        end
      end)

    # Return delivery results
    delivery_results
  end

  @impl GenServer
  def handle_info({:notify_subscribers, message}, state) do
    case message do
      {:signal, signal} ->
        notify_signal_subscribers(signal.id, message, state)

      {:signal_delivered, signal_id} ->
        notify_signal_subscribers(signal_id, message, state)

      {:signal_failed, signal_id, _reason} ->
        notify_signal_subscribers(signal_id, message, state)
    end

    {:noreply, state}
  end

  defp notify_signal_subscribers(signal_id, message, state) do
    state.subscribers
    |> Map.get(signal_id, MapSet.new())
    |> Enum.each(fn pid ->
      try do
        Process.send(pid, message, [:noconnect])
      catch
        # Subscriber might be dead, ignore
        _kind, _reason -> :ok
      end
    end)
  end
end
