defmodule Lux.Web3.EventMonitor.Store do
  @moduledoc """
  In-memory event persistence used by the event monitor and tests.

  The storage API is deliberately small and ordered, so a durable adapter can
  later implement the same semantics with Postgres, SQLite, or an external log.
  """

  use Agent

  alias Lux.Web3.EventMonitor.Event

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    start_opts =
      case Keyword.get(opts, :name) do
        nil -> []
        name -> [name: name]
      end

    Agent.start_link(fn -> %{events: %{}} end, start_opts)
  end

  @spec put(Event.t()) :: :ok
  def put(%Event{} = event), do: put(__MODULE__, event)

  @spec put(Agent.agent(), Event.t()) :: :ok
  def put(store, %Event{} = event) do
    Agent.update(store, fn state ->
      put_in(state.events[Event.event_key(event)], event)
    end)
  end

  @spec put_many([Event.t()]) :: :ok
  def put_many(events) when is_list(events), do: put_many(__MODULE__, events)

  @spec put_many(Agent.agent(), [Event.t()]) :: :ok
  def put_many(store, events) when is_list(events) do
    Agent.update(store, fn state ->
      Enum.reduce(events, state, fn %Event{} = event, acc ->
        put_in(acc.events[Event.event_key(event)], event)
      end)
    end)
  end

  @spec list() :: [Event.t()]
  def list, do: list(__MODULE__, [])

  @spec list(keyword()) :: [Event.t()]
  def list(opts) when is_list(opts), do: list(__MODULE__, opts)

  @spec list(Agent.agent(), keyword()) :: [Event.t()]
  def list(store, opts) do
    Agent.get(store, fn state ->
      state.events
      |> Map.values()
      |> filter(opts)
      |> Enum.sort_by(&{&1.block_number, &1.log_index})
    end)
  end

  @spec replay(String.t()) :: [Event.t()]
  def replay(subscription_id), do: replay(__MODULE__, subscription_id)

  @spec replay(Agent.agent(), String.t()) :: [Event.t()]
  def replay(store, subscription_id) do
    list(store, subscription_id: subscription_id)
  end

  @spec clear() :: :ok
  def clear, do: clear(__MODULE__)

  @spec clear(Agent.agent()) :: :ok
  def clear(store) do
    Agent.update(store, fn _state -> %{events: %{}} end)
  end

  defp filter(events, opts) do
    Enum.filter(events, fn event ->
      Enum.all?(opts, fn
        {:subscription_id, value} -> event.subscription_id == value
        {:chain_id, value} -> event.chain_id == value
        {:contract_address, value} -> event.contract_address == String.downcase(value)
        {:from_block, value} -> event.block_number >= value
        {:to_block, value} -> event.block_number <= value
        _ -> true
      end)
    end)
  end
end
