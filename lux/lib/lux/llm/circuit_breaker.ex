defmodule Lux.LLM.CircuitBreaker do
  @moduledoc """
  Circuit breaker implementation for provider health management.

  Three-state pattern: `:closed` (normal) → `:open` (tripped) → `:half_open` (probing).

  ## Configuration

  - `:failure_threshold` - failures before opening (default: 5)
  - `:reset_timeout` - ms before half-open (default: 30_000)
  - `:half_open_max_calls` - calls allowed in half-open (default: 1)
  - `:success_threshold` - successes in half-open to close (default: 1)

  """

  use GenServer

  require Logger

  @type provider_name :: atom()
  @type circuit_state :: :closed | :open | :half_open
  @type circuit_info :: %{
          state: circuit_state(),
          failure_count: non_neg_integer(),
          success_count: non_neg_integer(),
          last_failure_at: DateTime.t() | nil,
          opened_at: DateTime.t() | nil,
          half_open_calls: non_neg_integer()
        }
  @type config :: %{
          failure_threshold: pos_integer(),
          reset_timeout: pos_integer(),
          half_open_max_calls: pos_integer(),
          success_threshold: pos_integer()
        }
  @type t :: %{
          circuits: %{provider_name() => circuit_info()},
          config: config()
        }

  @default_failure_threshold 5
  @default_reset_timeout 30_000
  @default_half_open_max_calls 1
  @default_success_threshold 1

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec allow_request?(provider_name(), GenServer.server()) :: boolean()
  def allow_request?(provider, server \\ __MODULE__) do
    GenServer.call(server, {:allow_request?, provider})
  end

  @spec record_success(provider_name(), GenServer.server()) :: :ok
  def record_success(provider, server \\ __MODULE__) do
    GenServer.cast(server, {:record_success, provider})
  end

  @spec record_failure(provider_name(), GenServer.server()) :: :ok
  def record_failure(provider, server \\ __MODULE__) do
    GenServer.cast(server, {:record_failure, provider})
  end

  @spec get_state(provider_name(), GenServer.server()) :: {:ok, circuit_state()}
  def get_state(provider, server \\ __MODULE__) do
    GenServer.call(server, {:get_state, provider})
  end

  @spec get_info(provider_name(), GenServer.server()) :: {:ok, circuit_info()}
  def get_info(provider, server \\ __MODULE__) do
    GenServer.call(server, {:get_info, provider})
  end

  @spec reset(provider_name(), GenServer.server()) :: :ok
  def reset(provider, server \\ __MODULE__) do
    GenServer.cast(server, {:reset, provider})
  end

  @spec get_all_info(GenServer.server()) :: {:ok, %{provider_name() => circuit_info()}}
  def get_all_info(server \\ __MODULE__) do
    GenServer.call(server, :get_all_info)
  end

  # === Server Callbacks ===

  @impl true
  def init(opts) do
    config = %{
      failure_threshold: Keyword.get(opts, :failure_threshold, @default_failure_threshold),
      reset_timeout: Keyword.get(opts, :reset_timeout, @default_reset_timeout),
      half_open_max_calls: Keyword.get(opts, :half_open_max_calls, @default_half_open_max_calls),
      success_threshold: Keyword.get(opts, :success_threshold, @default_success_threshold)
    }

    {:ok, %{circuits: %{}, config: config}}
  end

  @impl true
  def handle_call({:allow_request?, provider}, _from, state) do
    {circuit, state} = get_or_create_circuit(state, provider)
    {circuit, state} = maybe_transition_to_half_open(circuit, state, provider)

    case circuit.state do
      :closed ->
        {:reply, true, state}

      :open ->
        {:reply, false, state}

      :half_open ->
        if circuit.half_open_calls < state.config.half_open_max_calls do
          updated_circuit = %{circuit | half_open_calls: circuit.half_open_calls + 1}
          updated_state = put_in(state, [:circuits, provider], updated_circuit)
          {:reply, true, updated_state}
        else
          {:reply, false, state}
        end
    end
  end

  @impl true
  def handle_call({:get_state, provider}, _from, state) do
    {circuit, state} = get_or_create_circuit(state, provider)
    {circuit, state} = maybe_transition_to_half_open(circuit, state, provider)
    {:reply, {:ok, circuit.state}, state}
  end

  @impl true
  def handle_call({:get_info, provider}, _from, state) do
    {circuit, state} = get_or_create_circuit(state, provider)
    {circuit, state} = maybe_transition_to_half_open(circuit, state, provider)
    {:reply, {:ok, circuit}, state}
  end

  @impl true
  def handle_call(:get_all_info, _from, state) do
    {:reply, {:ok, state.circuits}, state}
  end

  @impl true
  def handle_cast({:record_success, provider}, state) do
    {circuit, state} = get_or_create_circuit(state, provider)

    updated_circuit =
      case circuit.state do
        :closed ->
          %{circuit | failure_count: 0, success_count: circuit.success_count + 1}

        :half_open ->
          new_success = circuit.success_count + 1

          if new_success >= state.config.success_threshold do
            emit_telemetry(:state_change, provider, :half_open, :closed)
            Logger.info("[CircuitBreaker] #{provider} circuit closed after recovery")
            %{circuit | state: :closed, failure_count: 0, success_count: 0, opened_at: nil, half_open_calls: 0}
          else
            %{circuit | success_count: new_success}
          end

        :open ->
          circuit
      end

    {:noreply, put_in(state, [:circuits, provider], updated_circuit)}
  end

  @impl true
  def handle_cast({:record_failure, provider}, state) do
    {circuit, state} = get_or_create_circuit(state, provider)
    now = DateTime.utc_now()

    updated_circuit =
      case circuit.state do
        :closed ->
          new_count = circuit.failure_count + 1

          if new_count >= state.config.failure_threshold do
            emit_telemetry(:state_change, provider, :closed, :open)
            Logger.warning("[CircuitBreaker] #{provider} circuit opened after #{new_count} failures")
            %{circuit | state: :open, failure_count: new_count, last_failure_at: now, opened_at: now}
          else
            %{circuit | failure_count: new_count, last_failure_at: now}
          end

        :half_open ->
          emit_telemetry(:state_change, provider, :half_open, :open)
          Logger.warning("[CircuitBreaker] #{provider} circuit re-opened after half-open failure")
          %{circuit | state: :open, failure_count: circuit.failure_count + 1, success_count: 0,
            last_failure_at: now, opened_at: now, half_open_calls: 0}

        :open ->
          %{circuit | last_failure_at: now}
      end

    {:noreply, put_in(state, [:circuits, provider], updated_circuit)}
  end

  @impl true
  def handle_cast({:reset, provider}, state) do
    {circuit, state} = get_or_create_circuit(state, provider)

    if circuit.state != :closed do
      emit_telemetry(:state_change, provider, circuit.state, :closed)
      Logger.info("[CircuitBreaker] #{provider} circuit manually reset")
    end

    {:noreply, put_in(state, [:circuits, provider], new_circuit())}
  end

  # === Private ===

  defp get_or_create_circuit(state, provider) do
    case Map.get(state.circuits, provider) do
      nil ->
        circuit = new_circuit()
        {circuit, put_in(state, [:circuits, provider], circuit)}

      circuit ->
        {circuit, state}
    end
  end

  defp new_circuit do
    %{state: :closed, failure_count: 0, success_count: 0,
      last_failure_at: nil, opened_at: nil, half_open_calls: 0}
  end

  defp maybe_transition_to_half_open(circuit, state, provider) do
    case circuit.state do
      :open ->
        if should_transition_to_half_open?(circuit, state.config) do
          emit_telemetry(:state_change, provider, :open, :half_open)
          Logger.info("[CircuitBreaker] #{provider} circuit transitioned to half-open")
          updated = %{circuit | state: :half_open, success_count: 0, half_open_calls: 0}
          {updated, put_in(state, [:circuits, provider], updated)}
        else
          {circuit, state}
        end

      _ ->
        {circuit, state}
    end
  end

  defp should_transition_to_half_open?(%{opened_at: nil}, _config), do: false

  defp should_transition_to_half_open?(%{opened_at: opened_at}, config) do
    DateTime.diff(DateTime.utc_now(), opened_at, :millisecond) >= config.reset_timeout
  end

  defp emit_telemetry(event_type, provider, from_state, to_state) do
    :telemetry.execute(
      [:lux, :llm, :circuit_breaker, event_type],
      %{count: 1},
      %{provider: provider, from_state: from_state, to_state: to_state, timestamp: DateTime.utc_now()}
    )
  end
end
