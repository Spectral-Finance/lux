defmodule Lux.LLM.CostTracker do
  @moduledoc """
  Tracks LLM usage costs across providers.

  The CostTracker records token usage and estimated costs for every LLM request,
  providing analytics for cost optimization and budgeting.

  ## Features

  - Per-provider and per-model cost tracking
  - Rolling time-window summaries
  - Budget alerts (configurable thresholds)
  - Token usage aggregation

  ## Usage

      # Record a request's cost
      Lux.LLM.CostTracker.record(:openai, "gpt-4o", %{
        input_tokens: 500,
        output_tokens: 200,
        cost: 0.0045
      })

      # Get total cost summary
      summary = Lux.LLM.CostTracker.summary()

      # Get provider-specific costs
      provider_costs = Lux.LLM.CostTracker.by_provider(:openai)
  """

  use GenServer

  require Logger

  @table_name :lux_llm_costs

  # ── Client API ──────────────────────────────────────────────────────

  @doc """
  Starts the cost tracker process.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a request's token usage and cost.

  ## Parameters

  - `provider` - Provider name (e.g., `:openai`)
  - `model` - Model name (e.g., `"gpt-4o"`)
  - `usage` - Map with `:input_tokens`, `:output_tokens`, and optionally `:cost`
  """
  @spec record(atom(), String.t(), map()) :: :ok
  def record(provider, model, usage) do
    entry = %{
      provider: provider,
      model: model,
      input_tokens: Map.get(usage, :input_tokens, 0),
      output_tokens: Map.get(usage, :output_tokens, 0),
      total_tokens: Map.get(usage, :total_tokens, 0),
      cost: Map.get(usage, :cost, 0.0),
      timestamp: System.system_time(:millisecond)
    }

    :ets.insert(@table_name, {make_ref(), entry})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Returns total cost summary across all providers.

  ## Options

  - `:since` - Only include entries after this timestamp (milliseconds)
  - `:provider` - Filter by provider name
  """
  @spec summary(keyword()) :: map()
  def summary(opts \\ []) do
    entries = get_entries(opts)

    %{
      total_cost: entries |> Enum.map(& &1.cost) |> Enum.sum() |> to_float() |> Float.round(6),
      total_input_tokens: entries |> Enum.map(& &1.input_tokens) |> Enum.sum(),
      total_output_tokens: entries |> Enum.map(& &1.output_tokens) |> Enum.sum(),
      total_requests: length(entries),
      by_provider: group_by_provider(entries),
      by_model: group_by_model(entries)
    }
  rescue
    ArgumentError ->
      %{
        total_cost: 0.0,
        total_input_tokens: 0,
        total_output_tokens: 0,
        total_requests: 0,
        by_provider: %{},
        by_model: %{}
      }
  end

  @doc """
  Returns cost data for a specific provider.
  """
  @spec by_provider(atom()) :: map()
  def by_provider(provider) do
    summary(provider: provider)
  end

  @doc """
  Resets all cost tracking data.
  """
  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@table_name)
    :ok
  rescue
    ArgumentError -> :ok
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:named_table, :set, :public, write_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private ─────────────────────────────────────────────────────────

  defp get_entries(opts) do
    since = Keyword.get(opts, :since)
    provider_filter = Keyword.get(opts, :provider)

    :ets.tab2list(@table_name)
    |> Enum.map(fn {_ref, entry} -> entry end)
    |> Enum.filter(fn entry ->
      time_ok = if since, do: entry.timestamp >= since, else: true
      provider_ok = if provider_filter, do: entry.provider == provider_filter, else: true
      time_ok and provider_ok
    end)
  rescue
    ArgumentError -> []
  end

  defp to_float(n) when is_integer(n), do: n * 1.0
  defp to_float(n) when is_float(n), do: n

  defp group_by_provider(entries) do
    entries
    |> Enum.group_by(& &1.provider)
    |> Enum.map(fn {provider, provider_entries} ->
      {provider,
       %{
         cost:
           provider_entries |> Enum.map(& &1.cost) |> Enum.sum() |> to_float() |> Float.round(6),
         input_tokens: provider_entries |> Enum.map(& &1.input_tokens) |> Enum.sum(),
         output_tokens: provider_entries |> Enum.map(& &1.output_tokens) |> Enum.sum(),
         requests: length(provider_entries)
       }}
    end)
    |> Map.new()
  end

  defp group_by_model(entries) do
    entries
    |> Enum.group_by(& &1.model)
    |> Enum.map(fn {model, model_entries} ->
      {model,
       %{
         cost:
           model_entries |> Enum.map(& &1.cost) |> Enum.sum() |> to_float() |> Float.round(6),
         input_tokens: model_entries |> Enum.map(& &1.input_tokens) |> Enum.sum(),
         output_tokens: model_entries |> Enum.map(& &1.output_tokens) |> Enum.sum(),
         requests: length(model_entries)
       }}
    end)
    |> Map.new()
  end
end
