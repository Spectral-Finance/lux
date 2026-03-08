defmodule Lux.Integrations.Web3.Events.SubscriptionManager do
  @moduledoc """
  GenServer for managing contract event subscriptions.

  Tracks subscriptions by contract address, event types, and chains.
  Supports adding/removing subscriptions and querying active ones.
  """

  use GenServer

  defstruct subscriptions: %{}, next_id: 1

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Subscribe to events from a contract."
  def subscribe(pid \\ __MODULE__, params) do
    GenServer.call(pid, {:subscribe, params})
  end

  @doc "Unsubscribe by subscription ID."
  def unsubscribe(pid \\ __MODULE__, sub_id) do
    GenServer.call(pid, {:unsubscribe, sub_id})
  end

  @doc "List all active subscriptions."
  def list(pid \\ __MODULE__) do
    GenServer.call(pid, :list)
  end

  @doc "Get subscriptions for a specific contract."
  def for_contract(pid \\ __MODULE__, address) do
    GenServer.call(pid, {:for_contract, address})
  end

  @doc "Get subscriptions for a specific chain."
  def for_chain(pid \\ __MODULE__, chain) do
    GenServer.call(pid, {:for_chain, chain})
  end

  # Server

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_call({:subscribe, params}, _from, state) do
    sub = %{
      id: state.next_id,
      contract_address: params[:contract_address] || params["contract_address"],
      chain: params[:chain] || params["chain"] || :ethereum,
      event_types: params[:event_types] || params["event_types"] || [:all],
      topics: params[:topics] || params["topics"],
      webhook_url: params[:webhook_url] || params["webhook_url"],
      callback: params[:callback],
      created_at: DateTime.utc_now(),
      active: true
    }

    subs = Map.put(state.subscriptions, state.next_id, sub)
    {:reply, {:ok, sub}, %{state | subscriptions: subs, next_id: state.next_id + 1}}
  end

  @impl true
  def handle_call({:unsubscribe, sub_id}, _from, state) do
    case Map.get(state.subscriptions, sub_id) do
      nil -> {:reply, {:error, :not_found}, state}
      _sub ->
        subs = Map.delete(state.subscriptions, sub_id)
        {:reply, :ok, %{state | subscriptions: subs}}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.values(state.subscriptions), state}
  end

  @impl true
  def handle_call({:for_contract, address}, _from, state) do
    addr_down = String.downcase(address)
    matches = state.subscriptions
      |> Map.values()
      |> Enum.filter(&(String.downcase(&1.contract_address) == addr_down))
    {:reply, matches, state}
  end

  @impl true
  def handle_call({:for_chain, chain}, _from, state) do
    matches = state.subscriptions
      |> Map.values()
      |> Enum.filter(&(&1.chain == chain))
    {:reply, matches, state}
  end
end
