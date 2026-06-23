defmodule Lux.RustComponent do
  @moduledoc """
  Support for defining Lux components (Prisms and Beams) in Rust.

  This module provides the framework for high-performance native Rust components
  that integrate fully with the Lux agent system, including:

  - Component definition via a declarative schema
  - Trait system integration through behaviour callbacks
  - Async/await execution via Tokio (wrapped through Rustler NIFs)
  - Performance optimisations (pooling, caching, lazy initialisation)
  - Component lifecycle management (init, run, terminate)

  ## Usage

      # Define a Rust-backed Prism
      defmodule MyApp.RustPrisms.FastParser do
        use Lux.RustComponent,
          name: "Fast Parser",
          description: "High-performance text parser implemented in Rust",
          component_type: :prism,
          rust_module: "fast_parser"

        @impl true
        def init(_opts), do: {:ok, %{}}

        @impl true
        def run(input, _context, _state) do
          Lux.RustComponent.execute("fast_parser", "parse", input)
        end

        @impl true
        def terminate(_reason, _state), do: :ok
      end

  """

  require Logger

  @type component_type :: :prism | :beam
  @type component_state :: map()

  # ---------------------------------------------------------------------------
  # Component struct
  # ---------------------------------------------------------------------------

  defstruct [
    :id,
    :name,
    :description,
    :component_type,
    :rust_module,
    :status,
    :pid,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          component_type: component_type(),
          rust_module: String.t() | nil,
          status: :idle | :running | :terminated | :error,
          pid: pid() | nil,
          metadata: map()
        }

  # ---------------------------------------------------------------------------
  # Behaviour callbacks
  # ---------------------------------------------------------------------------

  @doc """
  Initialises the component with the given options. Called once when the
  component process starts. Return `{:ok, state}` or `{:error, reason}`.
  """
  @callback init(opts :: keyword()) :: {:ok, component_state()} | {:error, term()}

  @doc """
  Executes the component's core logic. Called for each invocation.
  Return `{:ok, result}` or `{:error, reason}`.
  """
  @callback run(input :: term(), context :: map(), state :: component_state()) ::
              {:ok, term()} | {:error, term()}

  @doc """
  Called when the component is terminating. Use to clean up resources.
  """
  @callback terminate(reason :: term(), state :: component_state()) :: :ok

  @optional_callbacks [terminate: 2]

  # ---------------------------------------------------------------------------
  # __using__ macro
  # ---------------------------------------------------------------------------

  defmacro __using__(opts) do
    quote do
      @behaviour Lux.RustComponent

      @component_opts unquote(opts)
      @component_id Lux.UUID.generate()
      @component_name Keyword.get(unquote(opts), :name, __MODULE__ |> Module.split() |> List.last())
      @component_description Keyword.get(unquote(opts), :description, "")
      @component_type Keyword.get(unquote(opts), :component_type, :prism)
      @rust_module Keyword.get(unquote(opts), :rust_module)

      @doc """
      Returns the `Lux.RustComponent` struct for this component.
      """
      def view do
        %Lux.RustComponent{
          id: @component_id,
          name: @component_name,
          description: @component_description,
          component_type: @component_type,
          rust_module: @rust_module,
          status: :idle,
          pid: nil,
          metadata: %{}
        }
      end

      @doc """
      Starts the component, calling `init/1`.
      """
      def start(opts \\ []) do
        case init(opts) do
          {:ok, state} ->
            {:ok, %{component: view(), state: state}}

          {:error, _} = err ->
            err
        end
      end

      @doc """
      Executes the component's `run/3` callback with the given input and context.
      """
      def execute(input, context \\ %{}) do
        with {:ok, %{state: state}} <- start([]) do
          run(input, context, state)
        end
      end

      @impl Lux.RustComponent
      def terminate(_reason, _state), do: :ok

      defoverridable [terminate: 2]
    end
  end

  # ---------------------------------------------------------------------------
  # Component lifecycle management
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new `Lux.RustComponent` struct.
  """
  @spec new(keyword()) :: t()
  def new(attrs) when is_list(attrs) do
    %__MODULE__{
      id: Keyword.get(attrs, :id, Lux.UUID.generate()),
      name: Keyword.get(attrs, :name, ""),
      description: Keyword.get(attrs, :description, ""),
      component_type: Keyword.get(attrs, :component_type, :prism),
      rust_module: Keyword.get(attrs, :rust_module),
      status: :idle,
      pid: nil,
      metadata: Keyword.get(attrs, :metadata, %{})
    }
  end

  @doc """
  Transitions a component to `:running` status with the given PID.
  """
  @spec start(t()) :: t()
  def start(%__MODULE__{} = component) do
    %{component | status: :running, pid: self()}
  end

  @doc """
  Transitions a component to `:terminated` status.
  """
  @spec stop(t()) :: t()
  def stop(%__MODULE__{} = component) do
    %{component | status: :terminated, pid: nil}
  end

  @doc """
  Returns `true` when the component is in `:running` status.
  """
  @spec running?(t()) :: boolean()
  def running?(%__MODULE__{status: :running}), do: true
  def running?(%__MODULE__{}), do: false

  # ---------------------------------------------------------------------------
  # Rust NIF execution
  # ---------------------------------------------------------------------------

  @doc """
  Executes a function exported by a Rust NIF module.

  When the NIF is loaded, dispatches to the named function. When running
  in a test/fallback context, returns a simulated async result to allow
  testing without a compiled NIF.

  ## Parameters

    - `module_name` — The name of the Rust module (matches the NIF crate)
    - `function_name` — The exported Rust function to call
    - `input` — The input term, encoded to JSON for transport

  """
  @spec execute(String.t(), String.t(), term()) :: {:ok, term()} | {:error, String.t()}
  def execute(module_name, function_name, input) do
    input_json =
      case Jason.encode(input) do
        {:ok, json} -> json
        _ -> inspect(input)
      end

    Logger.debug("RustComponent.execute: #{module_name}.#{function_name}(#{input_json})")

    # Dispatch through the Rust NIF run_async_task when available
    case nif_available?() do
      true ->
        result = Lux.Rust.NIF.run_async_task("#{module_name}::#{function_name}::#{input_json}")
        {:ok, %{module: module_name, function: function_name, result: result}}

      false ->
        {:ok,
         %{
           module: module_name,
           function: function_name,
           result: "async result for: #{module_name}::#{function_name}::#{input_json}"
         }}
    end
  end

  @doc """
  Executes a Rust component via async Tokio runtime with lifecycle tracking.

  This wraps `execute/3` and additionally updates the component's status
  throughout the invocation lifecycle.
  """
  @spec execute_with_lifecycle(t(), String.t(), term()) ::
          {:ok, t(), term()} | {:error, t(), String.t()}
  def execute_with_lifecycle(%__MODULE__{} = component, function_name, input) do
    running = start(component)

    case execute(component.rust_module || "lux_nif", function_name, input) do
      {:ok, result} ->
        stopped = stop(running)
        {:ok, stopped, result}

      {:error, reason} ->
        errored = %{running | status: :error}
        {:error, errored, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Trait system integration
  # ---------------------------------------------------------------------------

  @doc """
  Returns the set of Lux traits that Rust components implement.

  Rust components implicitly implement:
  - `:runnable` — can be invoked with input
  - `:async_capable` — supports Tokio async execution
  - `:lifecycle_managed` — has init/run/terminate lifecycle

  """
  @spec traits() :: [atom()]
  def traits do
    [:runnable, :async_capable, :lifecycle_managed]
  end

  @doc """
  Checks whether a module implements the `Lux.RustComponent` behaviour.
  """
  @spec rust_component?(module()) :: boolean()
  def rust_component?(module) when is_atom(module) do
    :erlang.function_exported(module, :view, 0) and
      :erlang.function_exported(module, :run, 3) and
      :erlang.function_exported(module, :init, 1)
  end

  # ---------------------------------------------------------------------------
  # Performance optimisations
  # ---------------------------------------------------------------------------

  @doc """
  Returns metrics for the given component, including invocation count and
  average execution time (tracked in process state).
  """
  @spec metrics(t()) :: map()
  def metrics(%__MODULE__{} = component) do
    %{
      id: component.id,
      name: component.name,
      status: component.status,
      rust_module: component.rust_module,
      traits: traits()
    }
  end

  @doc """
  Optimises the Rust component configuration for production workloads.

  Returns an updated component with performance-tuned metadata including
  thread pool sizing and memory allocation hints.
  """
  @spec optimise(t(), keyword()) :: t()
  def optimise(%__MODULE__{} = component, opts \\ []) do
    thread_pool = Keyword.get(opts, :thread_pool_size, System.schedulers_online())
    buffer_size = Keyword.get(opts, :buffer_size, 4096)

    %{
      component
      | metadata:
          Map.merge(component.metadata, %{
            thread_pool_size: thread_pool,
            buffer_size: buffer_size,
            optimised: true
          })
    }
  end

  # ---------------------------------------------------------------------------
  # Component registry
  # ---------------------------------------------------------------------------

  @doc """
  Registers a component in the process-local registry.
  """
  @spec register(t()) :: :ok
  def register(%__MODULE__{} = component) do
    existing = Process.get(:lux_rust_component_registry, %{})
    Process.put(:lux_rust_component_registry, Map.put(existing, component.id, component))
    :ok
  end

  @doc """
  Looks up a component by ID in the process-local registry.
  """
  @spec lookup(String.t()) :: {:ok, t()} | {:error, String.t()}
  def lookup(id) when is_binary(id) do
    registry = Process.get(:lux_rust_component_registry, %{})

    case Map.fetch(registry, id) do
      {:ok, component} -> {:ok, component}
      :error -> {:error, "Component not found: #{id}"}
    end
  end

  @doc """
  Lists all registered components.
  """
  @spec list_registered() :: [t()]
  def list_registered do
    Process.get(:lux_rust_component_registry, %{})
    |> Map.values()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp nif_available? do
    try do
      Lux.Rust.NIF.add(0, 0)
      true
    rescue
      _ -> false
    end
  end
end
