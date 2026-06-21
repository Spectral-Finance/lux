defmodule Lux.LLM.Supervisor do
  @moduledoc """
  OTP Supervisor for the LLM subsystem.

  Manages the following child processes:
  - `Lux.LLM.Registry` - Provider registration and discovery
  - `Lux.LLM.ResponseCache` - Caching LLM responses
  - `Lux.LLM.CostTracker` - Tracking API usage and costs
  - `Lux.LLM.CircuitBreaker` - Circuit breaker for fault tolerance

  ## Usage

  The supervisor is typically started as part of your application's
  supervision tree:

      children = [
        {Lux.LLM.Supervisor, []}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)

  ## Configuration

  The supervisor accepts the following options:

  - `:name` - The name to register the supervisor under (default: `Lux.LLM.Supervisor`)
  - `:registry` - Options for the Registry GenServer
  - `:response_cache` - Options for the ResponseCache GenServer
  - `:cost_tracker` - Options for the CostTracker GenServer
  - `:circuit_breaker` - Options for the CircuitBreaker GenServer
  - `:disabled_children` - List of child modules to not start

  ## Example

      # Start with custom configuration
      Lux.LLM.Supervisor.start_link(
        response_cache: [ttl: :timer.hours(2)],
        cost_tracker: [budget_limit: 100.0],
        circuit_breaker: [failure_threshold: 10]
      )
  """

  use Supervisor

  alias Lux.LLM.Registry
  alias Lux.LLM.ResponseCache
  alias Lux.LLM.CostTracker
  alias Lux.LLM.CircuitBreaker

  @type option ::
          {:name, Supervisor.name()}
          | {:registry, keyword()}
          | {:response_cache, keyword()}
          | {:cost_tracker, keyword()}
          | {:circuit_breaker, keyword()}
          | {:disabled_children, [module()]}

  @type options :: [option()]

  @default_name __MODULE__

  @doc """
  Starts the LLM supervisor.

  ## Options

  - `:name` - The name to register the supervisor under (default: `Lux.LLM.Supervisor`)
  - `:registry` - Options to pass to `Lux.LLM.Registry.start_link/1`
  - `:response_cache` - Options to pass to `Lux.LLM.ResponseCache.start_link/1`
  - `:cost_tracker` - Options to pass to `Lux.LLM.CostTracker.start_link/1`
  - `:circuit_breaker` - Options to pass to `Lux.LLM.CircuitBreaker.start_link/1`
  - `:disabled_children` - List of child modules to not start

  ## Returns

  - `{:ok, pid}` - The supervisor was started successfully
  - `{:error, reason}` - The supervisor failed to start
  """
  @spec start_link(options()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the child specification for this supervisor.
  """
  @spec child_spec(options()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @impl true
  @spec init(options()) :: {:ok, {Supervisor.sup_flags(), [Supervisor.child_spec()]}}
  def init(opts) do
    disabled = Keyword.get(opts, :disabled_children, [])

    children =
      [
        {Registry, Keyword.get(opts, :registry, [])},
        {ResponseCache, Keyword.get(opts, :response_cache, [])},
        {CostTracker, Keyword.get(opts, :cost_tracker, [])},
        {CircuitBreaker, Keyword.get(opts, :circuit_breaker, [])}
      ]
      |> Enum.reject(fn {module, _opts} -> module in disabled end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns a list of all child processes and their status.

  ## Parameters

  - `supervisor` - The supervisor name or PID (default: `Lux.LLM.Supervisor`)

  ## Returns

  A list of tuples containing child information.
  """
  @spec which_children(Supervisor.supervisor()) :: [
          {term(), pid() | :restarting, :worker | :supervisor, [module()] | :dynamic}
        ]
  def which_children(supervisor \\ @default_name) do
    Supervisor.which_children(supervisor)
  end

  @doc """
  Returns counts of children in various states.

  ## Parameters

  - `supervisor` - The supervisor name or PID (default: `Lux.LLM.Supervisor`)

  ## Returns

  A keyword list with counts for `:specs`, `:active`, `:supervisors`, and `:workers`.
  """
  @spec count_children(Supervisor.supervisor()) :: [
          specs: non_neg_integer(),
          active: non_neg_integer(),
          supervisors: non_neg_integer(),
          workers: non_neg_integer()
        ]
  def count_children(supervisor \\ @default_name) do
    Supervisor.count_children(supervisor)
  end

  @doc """
  Restarts a specific child process by its id.

  ## Parameters

  - `child_id` - The child module to restart
  - `supervisor` - The supervisor name or PID (default: `Lux.LLM.Supervisor`)

  ## Returns

  - `{:ok, pid}` - The child was restarted successfully
  - `{:error, reason}` - The child could not be restarted
  """
  @spec restart_child(module(), Supervisor.supervisor()) ::
          {:ok, pid()} | {:ok, pid(), term()} | {:error, term()}
  def restart_child(child_id, supervisor \\ @default_name) do
    with :ok <- Supervisor.terminate_child(supervisor, child_id) do
      Supervisor.restart_child(supervisor, child_id)
    end
  end

  @doc """
  Checks if all expected child processes are running.

  ## Parameters

  - `supervisor` - The supervisor name or PID (default: `Lux.LLM.Supervisor`)

  ## Returns

  - `:ok` - All children are running
  - `{:error, {:missing_children, list}}` - Some children are not running
  """
  @spec health_check(Supervisor.supervisor()) :: :ok | {:error, {:missing_children, [module()]}}
  def health_check(supervisor \\ @default_name) do
    expected_children = [Registry, ResponseCache, CostTracker, CircuitBreaker]

    running_children =
      supervisor
      |> Supervisor.which_children()
      |> Enum.map(fn
        {id, pid, _type, _modules} when is_pid(pid) -> id
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    missing =
      expected_children
      |> Enum.reject(fn child -> MapSet.member?(running_children, child) end)

    case missing do
      [] -> :ok
      _ -> {:error, {:missing_children, missing}}
    end
  end
end
