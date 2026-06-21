defmodule Lux.LLM.Registry do
  @moduledoc """
  ETS-backed registry for LLM providers with health tracking.

  ## Usage

      {:ok, _pid} = Lux.LLM.Registry.start_link()
      :ok = Lux.LLM.Registry.register(:openai, %{module: MyMod, config: %{}})
      {:ok, entry} = Lux.LLM.Registry.lookup(:openai)
      :ok = Lux.LLM.Registry.update_health(:openai, :degraded)

  """

  use GenServer

  require Logger

  @table __MODULE__

  @type provider_name :: atom()
  @type health_status :: :healthy | :degraded | :unhealthy
  @type provider_entry :: %{
          name: provider_name(),
          module: module(),
          config: map(),
          health: health_status(),
          registered_at: DateTime.t(),
          last_health_check: DateTime.t() | nil
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec register(provider_name(), map(), GenServer.server()) ::
          :ok | {:error, :already_registered}
  def register(name, opts, server \\ __MODULE__) do
    GenServer.call(server, {:register, name, opts})
  end

  @spec lookup(provider_name(), atom()) :: {:ok, provider_entry()} | {:error, :not_found}
  def lookup(name, server \\ __MODULE__) do
    table = if server == __MODULE__, do: @table, else: get_table(server)

    case :ets.lookup(table, name) do
      [{^name, entry}] -> {:ok, entry}
      [] -> {:error, :not_found}
    end
  end

  @spec update_health(provider_name(), health_status(), GenServer.server()) ::
          :ok | {:error, :not_found}
  def update_health(name, status, server \\ __MODULE__) do
    GenServer.call(server, {:update_health, name, status})
  end

  @spec unregister(provider_name(), GenServer.server()) :: :ok
  def unregister(name, server \\ __MODULE__) do
    GenServer.cast(server, {:unregister, name})
  end

  @spec list_healthy(GenServer.server()) :: {:ok, [provider_entry()]}
  def list_healthy(server \\ __MODULE__) do
    GenServer.call(server, :list_healthy)
  end

  @spec list_all(GenServer.server()) :: {:ok, [provider_entry()]}
  def list_all(server \\ __MODULE__) do
    GenServer.call(server, :list_all)
  end

  # === Server Callbacks ===

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :table, @table)
    table = :ets.new(table_name, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register, name, opts}, _from, state) do
    case :ets.lookup(state.table, name) do
      [{^name, _}] ->
        {:reply, {:error, :already_registered}, state}

      [] ->
        entry = %{
          name: name,
          module: Map.get(opts, :module),
          config: Map.get(opts, :config, %{}),
          health: :healthy,
          registered_at: DateTime.utc_now(),
          last_health_check: nil
        }

        :ets.insert(state.table, {name, entry})
        Logger.info("[Registry] Provider #{name} registered")
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:update_health, name, status}, _from, state) do
    case :ets.lookup(state.table, name) do
      [{^name, entry}] ->
        updated = %{entry | health: status, last_health_check: DateTime.utc_now()}
        :ets.insert(state.table, {name, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_healthy, _from, state) do
    providers =
      state.table
      |> :ets.tab2list()
      |> Enum.map(fn {_name, entry} -> entry end)
      |> Enum.filter(&(&1.health == :healthy))

    {:reply, {:ok, providers}, state}
  end

  @impl true
  def handle_call(:list_all, _from, state) do
    providers =
      state.table
      |> :ets.tab2list()
      |> Enum.map(fn {_name, entry} -> entry end)

    {:reply, {:ok, providers}, state}
  end

  @impl true
  def handle_cast({:unregister, name}, state) do
    :ets.delete(state.table, name)
    Logger.info("[Registry] Provider #{name} unregistered")
    {:noreply, state}
  end

  defp get_table(server) do
    :sys.get_state(server).table
  end
end
