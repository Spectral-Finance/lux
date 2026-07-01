defmodule Lux.LLM.CostTracker do
  @moduledoc """
  Tracks LLM usage costs and performance metrics using ETS.
  """
  use GenServer

  @table_name :llm_cost_log

  def start_link(opts \\\\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.merge(opts, name: __MODULE__))
  end

  def log(provider, model, input_tokens, output_tokens, duration_ms) do
    GenServer.cast(__MODULE__, {:log, provider, model, input_tokens, output_tokens, duration_ms})
  end

  def summary do
    GenServer.call(__MODULE__, :summary)
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(:ok) do
    :ets.new(@table_name, [:named_table, :public, :bag])
    {:ok, %{total_cost: 0.0, total_requests: 0}}
  end

  @impl true
  def handle_cast({:log, provider, model, input_tokens, output_tokens, duration_ms}, state) do
    cost_per_token = (provider[:cost_per_token] || 0.000003)
    estimated_cost = (input_tokens + output_tokens) * cost_per_token
    entry = %{
      provider: provider[:name],
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      duration_ms: duration_ms,
      estimated_cost: estimated_cost,
      timestamp: DateTime.utc_now()
    }
    :ets.insert(@table_name, {System.system_time(:second), entry})
    {:noreply, %{state | total_cost: state.total_cost + estimated_cost, total_requests: state.total_requests + 1}}
  end

  @impl true
  def handle_call(:summary, _from, state) do
    {:reply, %{total_cost: state.total_cost, total_requests: state.total_requests}, state}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    :ets.delete_all_objects(@table_name)
    {:reply, :ok, %{total_cost: 0.0, total_requests: 0}}
  end
end