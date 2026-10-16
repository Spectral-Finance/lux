defmodule Lux.LLM.CircuitBreaker do
  @moduledoc """
  Per-provider circuit breaker for the LLM provider layer.

  A provider that fails `failure_threshold` consecutive times is marked
  `:open` for `cooldown_ms`; while open, the router skips it. After the
  cooldown it moves to `:half_open` and lets a single probe request through:
  success closes the breaker, failure re-opens it.

  State is kept in ETS so `allow?/1` is a cheap read for the router hot path.
  """

  use GenServer

  require Logger

  @table :lux_llm_breaker

  @enforce_keys []
  defstruct [:provider, :state, :failures, :opened_at]

  @type state :: :closed | :open | :half_open
  @type t :: %__MODULE__{
          provider: module(),
          state: state(),
          failures: non_neg_integer(),
          opened_at: integer() | nil
        }

  # --- client API -----------------------------------------------------------

  @doc """
  Starts the breaker. Usually called by the application supervisor.

  Options:

    * `:failure_threshold` — consecutive failures before opening (default 5)
    * `:cooldown_ms` — how long the provider is skipped (default 30_000)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns `true` when the router may call the provider right now.
  """
  @spec allow?(module()) :: boolean()
  def allow?(provider) do
    case get(provider) do
      nil -> true
      %{state: :closed} -> true
      %{state: :half_open} -> true
      %{state: :open, opened_at: opened_at} -> maybe_transition(provider, opened_at)
    end
  end

  @doc """
  Current breaker state for a provider (`:closed` when never failed).
  """
  @spec status(module()) :: state()
  def status(provider) do
    case get(provider) do
      nil -> :closed
      %{state: state} -> state
    end
  end

  @doc """
  Records a successful call.
  """
  @spec record_success(module()) :: :ok
  def record_success(provider) do
    GenServer.cast(__MODULE__, {:success, provider})
  end

  @doc """
  Records a failed call; opens the breaker once the threshold is reached.
  """
  @spec record_failure(module()) :: :ok
  def record_failure(provider) do
    GenServer.cast(__MODULE__, {:failure, provider})
  end

  @doc """
  Test/reset helper: forget everything known about a provider.
  """
  @spec reset(module()) :: :ok
  def reset(provider) do
    GenServer.call(__MODULE__, {:reset, provider})
  end

  # --- server ---------------------------------------------------------------

  @impl GenServer
  def init(opts) do
    table = :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    {:ok,
     %{
       table: table,
       failure_threshold: Keyword.get(opts, :failure_threshold, 5),
       cooldown_ms: Keyword.get(opts, :cooldown_ms, 30_000)
     }}
  end

  @impl GenServer
  def handle_cast({:success, provider}, state) do
    put(provider, %__MODULE__{provider: provider, state: :closed, failures: 0, opened_at: nil})
    {:noreply, state}
  end

  def handle_cast({:failure, provider}, state) do
    current = get(provider) || %__MODULE__{provider: provider, state: :closed, failures: 0}

    failures = current.failures + 1

    if current.state == :half_open or failures >= state.failure_threshold do
      put(provider, %{current | state: :open, failures: failures, opened_at: now_ms()})

      Logger.warning(
        "lux llm circuit breaker: #{inspect(provider)} opened after #{failures} failures"
      )
    else
      put(provider, %{current | failures: failures})
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:reset, provider}, _from, state) do
    :ets.delete(state.table, provider)
    {:reply, :ok, state}
  end

  # --- internals ------------------------------------------------------------

  defp maybe_transition(provider, opened_at) do
    cooldown = cooldown_ms()

    if now_ms() - opened_at >= cooldown do
      GenServer.cast(__MODULE__, {:half_open, provider})
      true
    else
      false
    end
  end

  @impl GenServer
  def handle_cast({:half_open, provider}, state) do
    case get(provider) do
      %{state: :open} = entry ->
        put(provider, %{entry | state: :half_open})
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  defp get(provider) do
    case :ets.whereis(@table) do
      :undefined -> nil
      _tid -> :ets.lookup_element(@table, provider, 2)
    end
  rescue
    ArgumentError -> nil
  end

  defp put(provider, entry) do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _tid -> true = :ets.insert(@table, {provider, entry})
    end
  end

  defp cooldown_ms do
    Application.get_env(:lux, __MODULE__, []) |> Keyword.get(:cooldown_ms, 30_000)
  end

  defp now_ms, do: System.monotonic_time(:millisecond)
end
