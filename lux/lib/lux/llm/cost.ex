defmodule Lux.LLM.Cost do
  @moduledoc """
  Cost tracking and spend control for the LLM provider layer.

  Every call routed through `Lux.LLM.Router` is priced from the provider
  metadata (`Lux.LLM.Provider.meta/0`) and accumulated per provider/model.
  Aggregate views are served from ETS so `report/0` never blocks the router.

  ## Budgets

      # hard ceiling: once exceeded, Lux.LLM.Cost.exceeded?/0 returns true and
      # the router refuses new calls (unless forced)
      config :lux, Lux.LLM.Cost, budget_usd: 25.0

  ## Example

      Lux.LLM.Cost.record(:anthropic, "claude-3-haiku-20240307", 1200, 350)
      Lux.LLM.Cost.report()
      #=> %{total_usd: 0.0011, by_provider: %{anthropic: 0.0011}, calls: 1}

  """

  use GenServer

  require Logger

  @table :lux_llm_cost

  # --- client API -----------------------------------------------------------

  @doc """
  Starts the cost tracker. Usually called by the application supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records the token usage of a single call and returns its price in USD.

  `input_tokens` / `output_tokens` are the usage reported by the provider when
  available; `Lux.LLM.Router` estimates them from the prompt when the provider
  does not report usage.
  """
  @spec record(atom(), String.t(), non_neg_integer(), non_neg_integer()) :: float()
  def record(provider, model, input_tokens, output_tokens) do
    usage = %{
      provider: provider,
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost_usd: price(model, input_tokens, output_tokens),
      at: System.system_time(:millisecond)
    }

    :ets.insert(@table, {next_id(), usage})
    usage.cost_usd
  end

  @doc """
  Estimated price of a call, given the per-model metadata.
  """
  @spec price(String.t(), non_neg_integer(), non_neg_integer()) :: float()
  def price(model, input_tokens, output_tokens) do
    case pricing_for(model) do
      nil -> 0.0
      {in_rate, out_rate} -> in_rate * input_tokens / 1_000_000 + out_rate * output_tokens / 1_000_000
    end
  end

  @doc """
  Aggregate report over all recorded usage.
  """
  @spec report() :: %{total_usd: float(), by_provider: %{optional(atom()) => float()}, calls: non_neg_integer()}
  def report do
    usages = all()

    %{
      total_usd: Enum.reduce(usages, 0.0, fn u, acc -> acc + u.cost_usd end),
      by_provider:
        Enum.reduce(usages, %{}, fn u, acc ->
          Map.update(acc, u.provider, u.cost_usd, &(&1 + u.cost_usd))
        end),
      calls: length(usages)
    }
  end

  @doc """
  `true` when the configured budget has been exceeded.
  """
  @spec exceeded?() :: boolean()
  def exceeded? do
    case budget() do
      nil -> false
      budget -> report().total_usd >= budget
    end
  end

  @doc """
  Clears all recorded usage (test/reset helper).
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # --- server ---------------------------------------------------------------

  @impl GenServer
  def init(_opts) do
    _ =
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    true = :ets.insert(@table, {:next_id, 0})
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call(:reset, _from, state) do
    :ets.delete_all_objects(@table)
    true = :ets.insert(@table, {:next_id, 0})
    {:reply, :ok, state}
  end

  # --- internals ------------------------------------------------------------

  defp all do
    @table
    |> :ets.tab2list()
    |> Enum.reject(fn {key, _} -> key == :next_id end)
    |> Enum.map(fn {_key, usage} -> usage end)
  end

  defp next_id do
    :ets.update_counter(@table, :next_id, 1)
  end

  defp pricing_for(model) do
    providers()
    |> Enum.flat_map(fn module ->
      module.meta().models
      |> Enum.filter(fn m -> m.id == model end)
      |> Enum.map(fn m -> {m.input_cost_per_mtok, m.output_cost_per_mtok} end)
    end)
    |> List.first()
  end

  defp providers do
    Lux.LLM.Registry.list() |> Enum.map(& &1.module)
  end

  defp budget do
    Application.get_env(:lux, __MODULE__, []) |> Keyword.get(:budget_usd)
  end
end
