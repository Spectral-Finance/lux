defmodule Lux.LLM.Registry do
  @moduledoc """
  Runtime registry of LLM providers.

  The registry is the single source of truth used by `Lux.LLM.Selector` and
  `Lux.LLM.Router` to discover which providers are available, what they cost
  and whether they are currently healthy.

  State lives in a public, concurrently readable ETS table so hot paths
  (`Lux.LLM.Router`/`Lux.LLM.Selector`) never block on the GenServer, and in a
  GenServer that owns registration, config updates and health transitions.

  ## Usage

      Lux.LLM.Registry.register(Lux.LLM.Anthropic, model: "claude-3-haiku-20240307")
      Lux.LLM.Registry.register(Lux.LLM.OpenAI)

      Lux.LLM.Registry.list()
      #=> [%{module: Lux.LLM.Anthropic, status: :up, ...}, ...]

      Lux.LLM.Registry.mark_down(Lux.LLM.OpenAI)

  """

  use GenServer

  require Logger

  @table :lux_llm_providers

  @typedoc """
  A provider entry as stored in the registry.

    * `:module` — module implementing `Lux.LLM.Provider`
    * `:config` — options merged into every `c:Lux.LLM.call/3` call
    * `:meta` — result of `c:Lux.LLM.Provider.meta/0`
    * `:status` — `:up`, `:down` (provider disabled) or `:circuit_open`
    * `:default_model` — model forced by config, or `nil` for the provider default
    * `:weight` — base selection weight; higher means preferred at equal score
  """
  @type entry :: %{
          required(:module) => module(),
          required(:config) => map(),
          required(:meta) => Lux.LLM.Provider.provider_meta(),
          required(:status) => :up | :down | :circuit_open,
          required(:default_model) => String.t() | nil,
          required(:weight) => number()
        }

  # --- client API -----------------------------------------------------------

  @doc """
  Starts the registry. Usually called by the application supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers (or replaces) a provider.

  `config` may contain:

    * `:model` — force a model for this provider (overrides the provider default)
    * `:weight` — selection weight, default `1.0`
    * any other key is passed through to `c:Lux.LLM.call/3` unchanged
  """
  @spec register(module(), map() | keyword()) :: :ok | {:error, term()}
  def register(module, config \\ %{}) do
    GenServer.call(__MODULE__, {:register, module, Map.new(config)})
  end

  @doc """
  Removes a provider from the registry.
  """
  @spec unregister(module()) :: :ok
  def unregister(module) do
    GenServer.call(__MODULE__, {:unregister, module})
  end

  @doc """
  Returns all registered provider entries.
  """
  @spec list() :: [entry()]
  def list do
    case :ets.whereis(@table) do
      :undefined -> []
      _tid -> :ets.tab2list(@table) |> Enum.map(&elem(&1, 1))
    end
  end

  @doc """
  Returns a single provider entry, or `nil`.
  """
  @spec lookup(module()) :: entry() | nil
  def lookup(module) do
    case :ets.whereis(@table) do
      :undefined -> nil
      _tid -> :ets.lookup_element(@table, module, 2)
    end
  rescue
    ArgumentError -> nil
  end

  @doc """
  Returns provider entries that are currently usable (`status: :up`).
  """
  @spec available() :: [entry()]
  def available do
    Enum.filter(list(), &(&1.status == :up))
  end

  @doc """
  Marks a provider as administratively down (kept in the registry).
  """
  @spec mark_down(module()) :: :ok
  def mark_down(module) do
    GenServer.call(__MODULE__, {:status, module, :down})
  end

  @doc """
  Clears a `:down`/`:circuit_open` marker.
  """
  @spec mark_up(module()) :: :ok
  def mark_up(module) do
    GenServer.call(__MODULE__, {:status, module, :up})
  end

  # --- server ---------------------------------------------------------------

  @impl GenServer
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl GenServer
  def handle_call({:register, module, config}, _from, state) do
    case build_entry(module, config) do
      {:ok, entry} ->
        true = :ets.insert(state.table, {module, entry})
        Logger.debug("lux llm registry: registered #{inspect(module)}")
        {:reply, :ok, state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:unregister, module}, _from, state) do
    :ets.delete(state.table, module)
    {:reply, :ok, state}
  end

  def handle_call({:status, module, status}, _from, state) do
    _ =
      case lookup(module) do
        nil -> :ok
        entry -> true = :ets.insert(state.table, {module, %{entry | status: status}})
      end

    {:reply, :ok, state}
  end

  defp build_entry(module, config) do
    if Code.ensure_loaded?(module) and function_exported?(module, :meta, 0) do
      meta = module.meta()
      {model, call_config} = Map.pop(config, :model)
      {weight, call_config} = Map.pop(call_config, :weight)

      {:ok,
       %{
         module: module,
         config: call_config,
         meta: meta,
         status: :up,
         default_model: model || default_model(meta),
         weight: weight || 1.0
       }}
    else
      {:error, {:not_a_provider, module}}
    end
  end

  defp default_model(%{models: [first | _]}), do: first.id
  defp default_model(_), do: nil
end
