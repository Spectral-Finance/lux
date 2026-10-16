defmodule Lux.LLM.Stats do
  @moduledoc """
  Performance monitoring for the LLM provider layer.

  Every routed call emits Erlang `:telemetry` events:

    * `[:lux, :llm, :call, :stop]` — measurements `%{duration: non_neg_integer()}`,
      metadata `%{provider: atom, model: String.t, status: :ok | :error, cost_usd: float}`
    * `[:lux, :llm, :call, :exception]` — measurements `%{duration: non_neg_integer()}`,
      metadata `%{provider: atom, model: String.t, kind: :throw | :error | :exit}`

  The same events are aggregated in ETS and served by `snapshot/0`, so teams
  that do not run a telemetry backend still get latency percentiles, error
  rates and spend per provider.
  """

  use GenServer

  require Logger

  @table :lux_llm_stats
  @max_latency_samples 100

  # --- client API -----------------------------------------------------------

  @doc """
  Starts the stats collector. Usually called by the application supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Wraps a provider call with timing, telemetry and aggregation.

  `fun` is a zero-arity function returning `{:ok, Lux.LLM.Response.t()}`
  or `{:error, term()}`. Returns the function's result unchanged.
  """
  @spec measure(atom(), String.t(), fun()) ::
          {:ok, Lux.LLM.Response.t()} | {:error, term()}
  def measure(provider, model, fun) do
    started = System.monotonic_time(:microsecond)

    try do
      case fun.() do
        {:ok, %{} = response} ->
          usage = extract_usage(response)
          duration = duration_ms(started)
          cost = cost_for(provider, model, usage)

          record(provider, model, duration, :ok, usage)
          emit_stop(provider, model, duration, :ok, cost)

          {:ok, response}

        {:error, _reason} = error ->
          duration = duration_ms(started)
          record(provider, model, duration, :error, %{})
          emit_stop(provider, model, duration, :error, 0.0)
          error
      end
    rescue
      e ->
        duration = duration_ms(started)
        record(provider, model, duration, :error, %{})
        :telemetry.execute([:lux, :llm, :call, :exception], %{duration: duration}, %{
          provider: provider,
          model: model,
          kind: :error,
          reason: Exception.message(e)
        })
        reraise e, __STACKTRACE__
    catch
      kind, value ->
        duration = duration_ms(started)
        record(provider, model, duration, :error, %{})
        :telemetry.execute([:lux, :llm, :call, :exception], %{duration: duration}, %{
          provider: provider,
          model: model,
          kind: kind,
          reason: inspect(value)
        })
        :erlang.raise(kind, value, __STACKTRACE__)
    end
  end

  @doc """
  Aggregated snapshot across providers.

      Lux.LLM.Stats.snapshot()
      #=> %{
      #     calls: 42,
      #     errors: 2,
      #     latency_ms: %{p50: 820, p95: 2400, max: 3100},
      #     providers: %{anthropic: %{calls: 40, errors: 2}}
      #   }
  """
  @spec snapshot() :: map()
  def snapshot do
    %{calls: calls, errors: errors, latencies: latencies, providers: providers} = state()

    %{
      calls: calls,
      errors: errors,
      latency_ms: percentiles(latencies),
      providers: providers
    }
  end

  # --- server ---------------------------------------------------------------

  @impl GenServer
  def init(_opts) do
    _ =
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true
      ])

    :ets.insert(@table, {:agg, initial_state()})
    {:ok, %{}}
  end

  @impl GenServer
  def handle_call(:reset, _from, state) do
    :ets.insert(@table, {:agg, initial_state()})
    {:reply, :ok, state}
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  # --- internals ------------------------------------------------------------

  defp initial_state do
    %{calls: 0, errors: 0, latencies: :queue.new(), providers: %{}}
  end

  defp state do
    [{:agg, agg}] = :ets.lookup(@table, :agg)
    agg
  end

  defp record(provider, model, duration, status, _usage) do
    agg = state()

    updated =
      agg
      |> Map.update!(:calls, &(&1 + 1))
      |> Map.update!(:errors, fn errors -> if status == :error, do: errors + 1, else: errors end)
      |> Map.update!(:latencies, fn q ->
        q = :queue.in(duration, q)

        if :queue.len(q) > @max_latency_samples do
          {{:value, _}, q} = :queue.out(q)
          q
        else
          q
        end
      end)
      |> update_in([:providers], fn providers ->
        entry =
          Map.get(providers, provider, %{
            name: provider,
            calls: 0,
            errors: 0,
            models: MapSet.new([])
          })

        entry = %{
          entry
          | calls: entry.calls + 1,
            errors: entry.errors + if(status == :error, do: 1, else: 0),
            models: MapSet.put(entry.models, model)
        }

        Map.put(providers, provider, Map.delete(entry, :name))
      end)

    true = :ets.insert(@table, {:agg, updated})
    :ok
  end

  defp emit_stop(provider, model, duration, status, cost) do
    :telemetry.execute(
      [:lux, :llm, :call, :stop],
      %{duration: duration},
      %{provider: provider, model: model, status: status, cost_usd: cost}
    )
  end

  defp duration_ms(started), do: div(System.monotonic_time(:microsecond) - started, 1000)

  defp extract_usage(%{usage: %{input_tokens: i, output_tokens: o}})
       when is_integer(i) and is_integer(o),
       do: %{input_tokens: i, output_tokens: o}

  defp extract_usage(_response), do: nil

  defp cost_for(_provider, _model, nil), do: 0.0

  defp cost_for(provider, model, usage) do
    meta = Lux.LLM.Provider.model_meta(provider, model)

    case meta do
      nil -> 0.0
      _ -> Lux.LLM.Cost.price(model, usage.input_tokens, usage.output_tokens)
    end
  end

  defp percentiles(latencies) do
    values = :queue.to_list(latencies)

    case values do
      [] ->
        %{p50: nil, p95: nil, max: nil}

      _ ->
        sorted = Enum.sort(values)

        %{
          p50: Enum.at(sorted, div(length(sorted), 2)),
          p95: Enum.at(sorted, trunc(length(sorted) * 0.95)),
          max: List.last(sorted)
        }
    end
  end
end
