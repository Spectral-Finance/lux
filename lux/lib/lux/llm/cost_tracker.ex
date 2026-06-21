defmodule Lux.LLM.CostTracker do
  @moduledoc """
  Telemetry-based cost and token usage monitoring for LLM providers.

  ## Usage

      {:ok, _pid} = Lux.LLM.CostTracker.start_link()
      Lux.LLM.CostTracker.record(:openai, %{input_tokens: 100, output_tokens: 50, cost: 0.003})
      {:ok, totals} = Lux.LLM.CostTracker.get_totals(:openai)

  """

  use GenServer

  require Logger

  @type provider_name :: atom()
  @type usage :: %{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          cost: float()
        }
  @type totals :: %{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer(),
          total_cost: float(),
          call_count: non_neg_integer()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records usage for a provider.

  ## Examples

      iex> Lux.LLM.CostTracker.record(:openai, %{input_tokens: 100, output_tokens: 50, cost: 0.003})
      :ok

  """
  @spec record(provider_name(), usage(), GenServer.server()) :: :ok
  def record(provider, usage, server \\ __MODULE__) do
    GenServer.cast(server, {:record, provider, usage})
  end

  @doc """
  Returns accumulated totals for a provider.
  """
  @spec get_totals(provider_name(), GenServer.server()) :: {:ok, totals()} | {:error, :not_found}
  def get_totals(provider, server \\ __MODULE__) do
    GenServer.call(server, {:get_totals, provider})
  end

  @doc """
  Returns accumulated totals for all tracked providers.
  """
  @spec get_all_totals(GenServer.server()) :: {:ok, %{provider_name() => totals()}}
  def get_all_totals(server \\ __MODULE__) do
    GenServer.call(server, :get_all_totals)
  end

  @doc """
  Resets totals for a provider to zero.
  """
  @spec reset(provider_name(), GenServer.server()) :: :ok
  def reset(provider, server \\ __MODULE__) do
    GenServer.cast(server, {:reset, provider})
  end

  # === Server Callbacks ===

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:record, provider, usage}, state) do
    current = Map.get(state, provider, zero_totals())

    updated = %{
      input_tokens: current.input_tokens + Map.get(usage, :input_tokens, 0),
      output_tokens: current.output_tokens + Map.get(usage, :output_tokens, 0),
      total_cost: current.total_cost + Map.get(usage, :cost, 0.0),
      call_count: current.call_count + 1
    }

    {:noreply, Map.put(state, provider, updated)}
  end

  @impl true
  def handle_cast({:reset, provider}, state) do
    {:noreply, Map.put(state, provider, zero_totals())}
  end

  @impl true
  def handle_call({:get_totals, provider}, _from, state) do
    case Map.get(state, provider) do
      nil -> {:reply, {:error, :not_found}, state}
      totals -> {:reply, {:ok, totals}, state}
    end
  end

  @impl true
  def handle_call(:get_all_totals, _from, state) do
    {:reply, {:ok, state}, state}
  end

  defp zero_totals do
    %{input_tokens: 0, output_tokens: 0, total_cost: 0.0, call_count: 0}
  end
end
