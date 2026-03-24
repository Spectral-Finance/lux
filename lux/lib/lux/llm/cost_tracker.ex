defmodule Lux.LLM.CostTracker do
  @moduledoc """
  Tracks and manages LLM API costs.

  Features:
  - Per-request cost tracking
  - Cost budgets and limits
  - Cost optimization suggestions
  - Historical cost analysis

  ## Usage

      # Record a request cost
      CostTracker.record(:openai, "gpt-4", 1000, 500)

      # Get total costs
      costs = CostTracker.get_total_costs()

      # Get costs by provider
      provider_costs = CostTracker.get_costs_by_provider(:openai)

      # Set a budget limit
      CostTracker.set_budget(:daily, 10.0)  # $10/day

  """

  use Agent

  @table_name :lux_llm_cost_tracker

  @type time_period :: :hourly | :daily | :weekly | :monthly
  @type cost :: float()

  @doc """
  Start the cost tracker agent.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> init_tracker() end, name: __MODULE__)
  end

  @doc """
  Record a cost for an API request.

  ## Parameters

    * `provider` - The LLM provider
    * `model` - The model used
    * `input_tokens` - Number of input tokens
    * `output_tokens` - Number of output tokens

  ## Examples

      iex> CostTracker.record(:openai, "gpt-4", 1000, 500)
      :ok

  """
  @spec record(atom(), String.t(), non_neg_integer(), non_neg_integer()) :: :ok
  def record(provider, model, input_tokens, output_tokens) do
    cost = calculate_cost(provider, model, input_tokens, output_tokens)

    Agent.update(__MODULE__, fn state ->
      now = DateTime.utc_now()
      timestamp = System.monotonic_time(:millisecond)

      entry = %{
        provider: provider,
        model: model,
        input_tokens: input_tokens,
        output_tokens: output_tokens,
        cost: cost,
        timestamp: timestamp,
        datetime: now
      }

      # Add to history
      :ets.insert(@table_name, {{:history, timestamp}, entry})

      # Update aggregates
      update_aggregates(provider, model, cost, now)

      # Update state
      Map.update!(state, :total_cost, &(&1 + cost))
      |> Map.update!(:total_requests, &(&1 + 1))
    end)
  end

  @doc """
  Calculate the cost for a request without recording.

  ## Examples

      iex> CostTracker.calculate_cost(:openai, "gpt-4", 1000, 500)
      0.06

  """
  @spec calculate_cost(atom(), String.t(), non_neg_integer(), non_neg_integer()) :: cost()
  def calculate_cost(provider, model, input_tokens, output_tokens) do
    alias Lux.LLM.ProviderRegistry

    config = ProviderRegistry.get_config(provider)

    case get_in(config, [:cost_per_1k_tokens, model]) do
      nil -> 0.0
      costs ->
        input_cost = Map.get(costs, :input, 0) * (input_tokens / 1000)
        output_cost = Map.get(costs, :output, 0) * (output_tokens / 1000)
        Float.round(input_cost + output_cost, 6)
    end
  end

  @doc """
  Get total costs.

  ## Examples

      iex> CostTracker.get_total_costs()
      %{cost: 10.50, requests: 100, tokens: 50000}

  """
  @spec get_total_costs() :: map()
  def get_total_costs do
    Agent.get(__MODULE__, fn state ->
      %{
        cost: Map.get(state, :total_cost, 0.0),
        requests: Map.get(state, :total_requests, 0),
        tokens: Map.get(state, :total_tokens, 0)
      }
    end)
  end

  @doc """
  Get costs by provider.

  ## Examples

      iex> CostTracker.get_costs_by_provider(:openai)
      %{cost: 5.25, requests: 50, ...}

  """
  @spec get_costs_by_provider(atom()) :: map()
  def get_costs_by_provider(provider) do
    case :ets.lookup(@table_name, {:provider, provider}) do
      [{_, data}] -> data
      [] -> %{cost: 0.0, requests: 0, tokens: 0}
    end
  end

  @doc """
  Get costs by model.

  ## Examples

      iex> CostTracker.get_costs_by_model(:openai, "gpt-4")
      %{cost: 2.50, requests: 20, ...}

  """
  @spec get_costs_by_model(atom(), String.t()) :: map()
  def get_costs_by_model(provider, model) do
    case :ets.lookup(@table_name, {:model, provider, model}) do
      [{_, data}] -> data
      [] -> %{cost: 0.0, requests: 0, tokens: 0}
    end
  end

  @doc """
  Get costs for a time period.

  ## Examples

      iex> CostTracker.get_costs_by_period(:daily)
      %{cost: 8.50, requests: 80, ...}

  """
  @spec get_costs_by_period(time_period()) :: map()
  def get_costs_by_period(period) do
    now = DateTime.utc_now()

    start_time = case period do
      :hourly -> DateTime.add(now, -1, :hour)
      :daily -> DateTime.add(now, -1, :day)
      :weekly -> DateTime.add(now, -7, :day)
      :monthly -> DateTime.add(now, -30, :day)
    end

    entries = get_history_since(start_time)

    %{
      cost: Enum.reduce(entries, 0.0, fn entry, acc -> acc + entry.cost end),
      requests: length(entries),
      input_tokens: Enum.reduce(entries, 0, fn e, acc -> acc + e.input_tokens end),
      output_tokens: Enum.reduce(entries, 0, fn e, acc -> acc + e.output_tokens end)
    }
  end

  @doc """
  Set a budget limit.

  ## Examples

      iex> CostTracker.set_budget(:daily, 10.0)
      :ok

  """
  @spec set_budget(time_period(), cost()) :: :ok
  def set_budget(period, limit) do
    Agent.update(__MODULE__, fn state ->
      budgets = Map.get(state, :budgets, %{})
      Map.put(state, :budgets, Map.put(budgets, period, limit))
    end)
  end

  @doc """
  Check if budget is exceeded.

  ## Examples

      iex> CostTracker.budget_exceeded?(:daily)
      false

  """
  @spec budget_exceeded?(time_period()) :: boolean()
  def budget_exceeded?(period) do
    budget = get_budget(period)
    current = get_costs_by_period(period)

    budget != nil and current.cost >= budget
  end

  @doc """
  Get the budget for a period.

  ## Examples

      iex> CostTracker.get_budget(:daily)
      10.0

  """
  @spec get_budget(time_period()) :: cost() | nil
  def get_budget(period) do
    Agent.get(__MODULE__, fn state ->
      get_in(state, [:budgets, period])
    end)
  end

  @doc """
  Get cost history.

  ## Examples

      iex> CostTracker.get_history(100)
      [%{provider: :openai, ...}, ...]

  """
  @spec get_history(pos_integer()) :: [map()]
  def get_history(limit \\ 100) do
    :ets.tab2list(@table_name)
    |> Enum.filter(fn
      {{:history, _}, _} -> true
      _ -> false
    end)
    |> Enum.sort_by(fn {{:history, timestamp}, _} -> timestamp end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {_, entry} -> entry end)
  end

  @doc """
  Reset all tracking data.

  ## Examples

      iex> CostTracker.reset()
      :ok

  """
  @spec reset() :: :ok
  def reset do
    Agent.update(__MODULE__, fn _state ->
      :ets.delete_all_objects(@table_name)
      init_state()
    end)
  end

  # Private functions

  defp init_tracker do
    if :ets.whereis(@table_name) == :undefined do
      :ets.new(@table_name, [:named_table, :set, :public])
    end
    init_state()
  end

  defp init_state do
    %{
      total_cost: 0.0,
      total_requests: 0,
      total_tokens: 0,
      budgets: %{}
    }
  end

  defp update_aggregates(provider, model, cost, now) do
    # Update provider aggregate
    provider_data = case :ets.lookup(@table_name, {:provider, provider}) do
      [{_, data}] -> data
      [] -> %{cost: 0.0, requests: 0, tokens: 0}
    end

    updated_provider = %{
      cost: provider_data.cost + cost,
      requests: provider_data.requests + 1,
      tokens: provider_data.tokens,
      last_request: now
    }

    :ets.insert(@table_name, {{:provider, provider}, updated_provider})

    # Update model aggregate
    model_data = case :ets.lookup(@table_name, {:model, provider, model}) do
      [{_, data}] -> data
      [] -> %{cost: 0.0, requests: 0, tokens: 0}
    end

    updated_model = %{
      cost: model_data.cost + cost,
      requests: model_data.requests + 1,
      tokens: model_data.tokens,
      last_request: now
    }

    :ets.insert(@table_name, {{:model, provider, model}, updated_model})
  end

  defp get_history_since(start_time) do
    :ets.tab2list(@table_name)
    |> Enum.filter(fn
      {{:history, _}, entry} ->
        DateTime.compare(entry.datetime, start_time) in [:gt, :eq]
      _ -> false
    end)
    |> Enum.map(fn {_, entry} -> entry end)
  end
end