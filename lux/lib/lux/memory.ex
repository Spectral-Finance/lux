defmodule Lux.Memory do
  @moduledoc """
  Core memory functionality for Lux agents and components.

  There are two ways to use memory:

  1. Named memories (defined as modules):
      defmodule MyAgentMemory do
        use Lux.Memory,
          backend: Lux.Memory.ETS,
          name: :my_agent_memory
      end

  2. Dynamic memories:
      {:ok, memory} = Lux.Memory.initialize(backend: Lux.Memory.ETS)
  """

  @registry_table :lux_memory_registry

  # Initialize registry table at module load time
  @registry_table
  |> :ets.whereis()
  |> case do
    :undefined -> :ets.new(@registry_table, [:set, :public, :named_table])
    _table_id -> :ok
  end

  @type memory_entry :: %{
          id: integer(),
          content: term(),
          type: memory_type(),
          timestamp: integer(),
          metadata: map()
        }

  @type memory_type :: :observation | :reflection | :interaction | :system
  @type memory_ref :: term()
  @type memory_opts :: keyword()
  @type backend_module :: module()

  @callback initialize(keyword()) :: {:ok, memory_ref()} | {:error, term()}
  @callback add(memory_ref(), content :: term(), type :: memory_type(), metadata :: map()) ::
              {:ok, memory_entry()} | {:error, term()}
  @callback recent(memory_ref(), n :: pos_integer()) ::
              {:ok, [memory_entry()]} | {:error, term()}
  @callback window(memory_ref(), start_time :: DateTime.t(), end_time :: DateTime.t()) ::
              {:ok, [memory_entry()]} | {:error, term()}
  @callback search(memory_ref(), query :: String.t()) ::
              {:ok, [memory_entry()]} | {:error, term()}

  defmacro __using__(opts) do
    quote location: :keep do
      @memory_opts unquote(opts)
      @backend Keyword.fetch!(@memory_opts, :backend)
      @memory_name Keyword.fetch!(@memory_opts, :name)

      def initialize do
        @backend.initialize(name: @memory_name)
      end

      def add(content, type \\ :observation, metadata \\ %{}) do
        @backend.add(@memory_name, content, type, metadata)
      end

      def recent(n) when is_integer(n) and n > 0 do
        @backend.recent(@memory_name, n)
      end

      def window(start_time, end_time) do
        @backend.window(@memory_name, start_time, end_time)
      end

      def search(query) do
        @backend.search(@memory_name, query)
      end
    end
  end

  def initialize(opts) do
    backend = Keyword.fetch!(opts, :backend)
    backend.initialize(opts)
  end

  def add(memory_ref, content, type \\ :observation, metadata \\ %{}) do
    impl_module(memory_ref).add(memory_ref, content, type, metadata)
  end

  def recent(memory_ref, n) when is_integer(n) and n > 0 do
    impl_module(memory_ref).recent(memory_ref, n)
  end

  def window(memory_ref, start_time, end_time) do
    impl_module(memory_ref).window(memory_ref, start_time, end_time)
  end

  def search(memory_ref, query) do
    impl_module(memory_ref).search(memory_ref, query)
  end

  defp impl_module(memory_ref) do
    case :ets.lookup(:lux_memory_registry, memory_ref) do
      [{^memory_ref, {_main_table, _counter_table, backend}}] -> backend
      [] -> raise "Memory reference #{inspect(memory_ref)} not found"
    end
  end
end
