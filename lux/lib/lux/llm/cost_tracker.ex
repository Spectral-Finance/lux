defmodule Lux.LLM.CostTracker do
  @moduledoc """
  Tracks token usage and costs across all LLM provider calls.

  Uses an ETS-backed store for fast concurrent writes. Provides
  real-time cost aggregation, per-model breakdowns, and budget
  enforcement.

  ## Usage

      # Track a call
      Lux.LLM.CostTracker.track(:openai, "gpt-4", 1500, 500, 0.045)

      # Get total spend
      Lux.LLM.CostTracker.total_spend()

      # Get per-model breakdown
      Lux.LLM.CostTracker.breakdown_by_model()

      # Check budget
      Lux.LLM.CostTracker.within_budget?(0.10)
  """

  use GenServer

  @table :lux_llm_cost_tracker

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Record a completed LLM call's token usage and cost.
  """
  @spec track(atom(), String.t(), pos_integer(), pos_integer(), float()) :: :ok
  def track(provider, model, input_tokens, output_tokens, cost_usd) do
    GenServer.cast(__MODULE__, {:track, provider, model, input_tokens, output_tokens, cost_usd})
  end

  @doc """
  Get the total spend across all providers and models.
  """
  @spec total_spend() :: float()
  def total_spend do
    GenServer.call(__MODULE__, :total_spend)
  end

  @doc """
  Get total token usage.
  """
  @spec total_tokens() :: %{input: pos_integer(), output: pos_integer()}
  def total_tokens do
    GenServer.call(__MODULE__, :total_tokens)
  end

  @doc """
  Get a breakdown of costs by model.
  """
  @spec breakdown_by_model() :: %{String.t() => %{cost: float(), calls: pos_integer(), input_tokens: pos_integer(), output_tokens: pos_integer()}}
  def breakdown_by_model do
    GenServer.call(__MODULE__, :breakdown_by_model)
  end

  @doc """
  Get a breakdown of costs by provider.
  """
  @spec breakdown_by_provider() :: %{atom() => %{cost: float(), calls: pos_integer()}}
  def breakdown_by_provider do
    GenServer.call(__MODULE__, :breakdown_by_provider)
  end

  @doc """
  Check if spending is within the given budget.
  """
  @spec within_budget?(float()) :: boolean()
  def within_budget?(budget_usd) do
    total_spend() <= budget_usd
  end

  @doc """
  Reset all tracking data.
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @doc """
  Estimate cost for a model given token counts.
  """
  @spec estimate_cost(String.t(), pos_integer(), pos_integer()) :: float()
  def estimate_cost(model, input_tokens, output_tokens) do
    costs = model_pricing()[model] || %{input: 0.001, output: 0.002}
    (input_tokens * costs.input + output_tokens * costs.output)
    |> Float.round(6)
  end

  @doc """
  Return the model pricing table.
  """
  @spec model_pricing() :: map()
  def model_pricing do
    %{
      "gpt-4"                => %{input: 0.00003, output: 0.00006},
      "gpt-4-turbo"          => %{input: 0.00001, output: 0.00003},
      "gpt-4o"               => %{input: 0.000005, output: 0.000015},
      "gpt-4o-mini"          => %{input: 0.00000015, output: 0.0000006},
      "gpt-3.5-turbo"        => %{input: 0.0000005, output: 0.0000015},
      "claude-3-opus"        => %{input: 0.000015, output: 0.000075},
      "claude-3-sonnet"      => %{input: 0.000003, output: 0.000015},
      "claude-3-haiku"       => %{input: 0.00000025, output: 0.00000125},
      "claude-3.5-sonnet"    => %{input: 0.000003, output: 0.000015},
      "gemini-pro"           => %{input: 0.00000125, output: 0.000005},
      "gemini-ultra"         => %{input: 0.000035, output: 0.000105},
      "gemini-1.5-pro"       => %{input: 0.0000035, output: 0.0000105},
      "gemini-1.5-flash"     => %{input: 0.000000075, output: 0.0000003},
      "llama3"               => %{input: 0.0, output: 0.0},
      "mistral"              => %{input: 0.0, output: 0.0}
    }
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:set, :public, :named_table])

    state = %{
      table: table,
      total_cost: 0.0,
      total_input_tokens: 0,
      total_output_tokens: 0,
      by_model: %{},
      by_provider: %{},
      call_count: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:track, provider, model, input_tokens, output_tokens, cost_usd}, state) do
    # Update by_model
    model_entry = Map.get(state.by_model, model, %{cost: 0.0, calls: 0, input_tokens: 0, output_tokens: 0})
    new_model_entry = %{model_entry |
      cost: model_entry.cost + cost_usd,
      calls: model_entry.calls + 1,
      input_tokens: model_entry.input_tokens + input_tokens,
      output_tokens: model_entry.output_tokens + output_tokens
    }

    # Update by_provider
    provider_entry = Map.get(state.by_provider, provider, %{cost: 0.0, calls: 0})
    new_provider_entry = %{provider_entry |
      cost: provider_entry.cost + cost_usd,
      calls: provider_entry.calls + 1
    }

    new_state = %{state |
      total_cost: state.total_cost + cost_usd,
      total_input_tokens: state.total_input_tokens + input_tokens,
      total_output_tokens: state.total_output_tokens + output_tokens,
      by_model: Map.put(state.by_model, model, new_model_entry),
      by_provider: Map.put(state.by_provider, provider, new_provider_entry),
      call_count: state.call_count + 1
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:total_spend, _from, state) do
    {:reply, Float.round(state.total_cost, 6), state}
  end

  def handle_call(:total_tokens, _from, state) do
    {:reply, %{input: state.total_input_tokens, output: state.total_output_tokens}, state}
  end

  def handle_call(:breakdown_by_model, _from, state) do
    {:reply, state.by_model, state}
  end

  def handle_call(:breakdown_by_provider, _from, state) do
    {:reply, state.by_provider, state}
  end

  def handle_call(:reset, _from, _state) do
    {:ok, new_state} = init([])
    {:reply, :ok, new_state}
  end
end
