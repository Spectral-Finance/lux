defmodule Lux.Rust.Component do
  @moduledoc """
  Rust Component Definition — defines the lifecycle and integration for
  Lux components backed by Rust NIFs or pure Elixir implementations.

  Components follow a lifecycle: `init -> validate -> handle_call -> terminate`.
  They integrate with Lux Prisms (data sources) and Beams (execution signals).
  """

  alias Lux.Rust.Component

  # ── Component Struct ──────────────────────────────────────────────────────

  defstruct [
    :name,
    :version,
    :description,
    :dependencies,
    :handlers,
    :state,
    status: :idle,
    config: %{},
    metadata: %{},
    registry: %{}
  ]

  @type handler_type :: :init | :validate | :handle_call | :terminate | :prism | :beam

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          description: String.t(),
          dependencies: [String.t()],
          handlers: %{handler_type() => function()},
          state: any(),
          status: :idle | :initializing | :active | :error | :terminated,
          config: map(),
          metadata: map(),
          registry: map()
        }

  @doc """
  Creates a new component definition.
  """
  def new(name, opts \\ []) do
    %Component{
      name: name,
      version: Keyword.get(opts, :version, "0.1.0"),
      description: Keyword.get(opts, :description, ""),
      dependencies: Keyword.get(opts, :dependencies, []),
      handlers: %{},
      config: Keyword.get(opts, :config, %{}),
      metadata: Keyword.get(opts, :metadata, %{}),
      state: nil,
      status: :idle,
      registry: %{}
    }
  end

  # ── Component Lifecycle ───────────────────────────────────────────────────

  @doc """
  Initializes the component with configuration.
  Returns `{:ok, component}` or `{:error, reason}`.
  """
  def init(%Component{} = component, init_fn \\ nil) do
    component = %{component | status: :initializing}

    result =
      case init_fn do
        nil ->
          # Default init: validate configuration
          validate_config(component.config)

        fun when is_function(fun, 1) ->
          fun.(component)

        fun when is_function(fun, 2) ->
          fun.(component, component.config)
      end

    case result do
      {:ok, state} ->
        {:ok, %{component | status: :active, state: state}}

      {:ok, state, handlers} when is_list(handlers) ->
        component = %{component | status: :active, state: state}
        {:ok, register_handlers(component, handlers)}

      {:error, reason} ->
        {:error, %{component | status: :error, state: reason}}
    end
  end

  @doc """
  Validates the component's current state.
  """
  def validate(%Component{} = component, validator \\ nil) do
    case validator do
      nil -> validate_config(component.config)
      fun when is_function(fun, 1) -> fun.(component)
      fun when is_function(fun, 2) -> fun.(component, component.state)
    end
  end

  @doc """
  Handles a call/message to the component.
  """
  def handle_call(%Component{} = component, message, handler_fn \\ nil) do
    case handler_fn do
      nil ->
        if component.status == :active do
          {:reply, :ok, component}
        else
          {:reply, {:error, :not_ready}, component}
        end

      fun when is_function(fun, 2) ->
        fun.(component, message)

      fun when is_function(fun, 3) ->
        fun.(component, message, component.state)
    end
  end

  @doc """
  Terminates the component, cleaning up resources.
  """
  def terminate(%Component{} = component, term_fn \\ nil) do
    result =
      case term_fn do
        nil -> :ok
        fun when is_function(fun, 1) -> fun.(component)
        fun when is_function(fun, 2) -> fun.(component, component.state)
      end

    {:ok, %{component | status: :terminated, state: nil}}
  end

  # ── Handler Registration ──────────────────────────────────────────────────

  @doc """
  Registers a handler function for the component.
  """
  def register_handler(%Component{} = component, type, handler_fn)
      when type in [:init, :validate, :handle_call, :terminate] do
    handlers = Map.put(component.handlers, type, handler_fn)
    %{component | handlers: handlers}
  end

  @doc """
  Registers one or more Prism (data source) integrations.
  """
  def register_prism(%Component{} = component, prism_name, query_fn) do
    prisms = Map.put(component.registry, {:prism, prism_name}, query_fn)
    %{component | registry: prisms}
  end

  @doc """
  Registers one or more Beam (execution signal) integrations.
  """
  def register_beam(%Component{} = component, beam_name, signal_fn) do
    beams = Map.put(component.registry, {:beam, beam_name}, signal_fn)
    %{component | registry: beams}
  end

  @doc """
  Executes a Prism data source query.
  """
  def query_prism(%Component{} = component, prism_name, params \\ %{}) do
    case Map.get(component.registry, {:prism, prism_name}) do
      nil -> {:error, "Prism #{prism_name} not registered"}
      fun when is_function(fun, 1) -> fun.(params)
      fun when is_function(fun, 2) -> fun.(component, params)
    end
  end

  @doc """
  Executes a Beam signal.
  """
  def emit_beam(%Component{} = component, beam_name, payload \\ %{}) do
    case Map.get(component.registry, {:beam, beam_name}) do
      nil -> {:error, "Beam #{beam_name} not registered"}
      fun when is_function(fun, 1) -> fun.(payload)
      fun when is_function(fun, 2) -> fun.(component, payload)
    end
  end

  # ── Lifecycle Supervisors ─────────────────────────────────────────────────

  @doc """
  Links two components together so they share lifecycle status.
  """
  def link(%Component{} = comp1, %Component{} = comp2) do
    linked = [comp1.name, comp2.name]
    %{
      comp1
      | dependencies: comp1.dependencies ++ [comp2.name],
        metadata: Map.put(comp1.metadata, :linked_to, linked)
    }
  end

  @doc """
  Creates a supervision tree from a list of components.
  """
  def supervise(components, strategy \\ :one_for_one) when is_list(components) do
    %{
      strategy: strategy,
      components: components,
      status: :idle
    }
  end

  # ── Framework Integration (Prisms / Beams) ────────────────────────────────

  @doc """
  Creates a Prism integration module definition.
  A Prism is a data source that can be queried.
  """
  defmacro defprism(name, do: block) do
    quote do
      def unquote(:"prism_#{name}")(params \\ %{}), do: unquote(block)
    end
  end

  @doc """
  Creates a Beam integration module definition.
  A Beam is an execution signal that emits events.
  """
  defmacro defbeam(name, do: block) do
    quote do
      def unquote(:"beam_#{name}")(payload \\ %{}), do: unquote(block)
    end
  end

  # ── Private Helpers ───────────────────────────────────────────────────────

  defp validate_config(config) when is_map(config) do
    {:ok, config}
  end

  defp validate_config(_invalid) do
    {:error, "Component config must be a map"}
  end

  defp register_handlers(component, handlers) when is_list(handlers) do
    Enum.reduce(handlers, component, fn
      {type, fun}, acc when type in [:init, :validate, :handle_call, :terminate] ->
        register_handler(acc, type, fun)

      {:prism, name, fun}, acc ->
        register_prism(acc, name, fun)

      {:beam, name, fun}, acc ->
        register_beam(acc, name, fun)

      _, acc ->
        acc
    end)
  end
end
