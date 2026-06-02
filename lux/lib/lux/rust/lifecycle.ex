defmodule Lux.Rust.Lifecycle do
  @moduledoc """
  Component lifecycle management for Rust components.

  Manages the lifecycle states and transitions of Rust-based components
  within the Lux framework, including initialization, execution,
  suspension, resumption, and shutdown.

  ## States

  - `:uninitialized` — component has not been initialized
  - `:initializing` — component is being set up
  - `:ready` — component is ready to execute
  - `:executing` — component is actively processing
  - `:suspended` — component is paused
  - `:error` — component encountered an error
  - `:shutting_down` — component is being torn down
  - `:terminated` — component has been shut down

  ## Transitions

      uninitialized -> initializing -> ready -> executing -> ready
      ready -> suspended -> ready
      executing -> error -> ready
      any -> shutting_down -> terminated
  """

  @allowed_transitions %{
    uninitialized: [:initializing, :shutting_down],
    initializing: [:ready, :error, :shutting_down],
    ready: [:executing, :suspended, :shutting_down],
    executing: [:ready, :error, :suspended, :shutting_down],
    suspended: [:ready, :shutting_down],
    error: [:ready, :shutting_down],
    shutting_down: [:terminated],
    terminated: []
  }

  @doc """
  Checks whether a state transition is allowed.
  """
  @spec valid_transition?(atom(), atom()) :: boolean()
  def valid_transition?(from, to) do
    case Map.fetch(@allowed_transitions, from) do
      {:ok, allowed} -> to in allowed
      :error -> false
    end
  end

  @doc """
  Returns all allowed transitions from a given state.
  """
  @spec allowed_transitions(atom()) :: [atom()]
  def allowed_transitions(state) do
    Map.get(@allowed_transitions, state, [])
  end

  @doc """
  Returns the standard lifecycle as a list of state/transition pairs.
  """
  @spec lifecycle_definition() :: %{String.t() => [String.t()]}
  def lifecycle_definition do
    Map.new(@allowed_transitions, fn {k, v} ->
      {Atom.to_string(k), Enum.map(v, &Atom.to_string/1)}
    end)
  end

  @doc """
  Initializes a Rust component, transitioning it to :ready state.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  @spec init(String.t(), String.t()) :: :ok | {:error, String.t()}
  def init(kind, name) do
    if Lux.Native.loaded?() do
      case Lux.Native.rust_component_init(kind, name) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
        other -> {:error, "Unexpected: #{inspect(other)}"}
      end
    else
      {:error, "Rust native library not loaded"}
    end
  end

  @doc """
  Shuts down a Rust component, transitioning it to :terminated state.
  """
  @spec shutdown(String.t(), String.t()) :: :ok | {:error, String.t()}
  def shutdown(kind, name) do
    if Lux.Native.loaded?() do
      case Lux.Native.rust_component_shutdown(kind, name) do
        :ok -> :ok
        {:error, reason} -> {:error, reason}
        other -> {:error, "Unexpected: #{inspect(other)}"}
      end
    else
      {:error, "Rust native library not loaded"}
    end
  end
end
