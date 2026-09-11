defmodule Lux.LLM.Telemetry do
  @moduledoc """
  Telemetry and Cost Tracking module for Lux LLM calls.

  Instruments LLM calls to measure latency and token usage, emits `:telemetry` events
  (`[:lux, :llm, :call, :start]`, `[:lux, :llm, :call, :stop]`, and `[:lux, :llm, :call, :exception]`),
  and calculates/normalizes token usage and costs in `Lux.Signal` metadata.
  """

  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Router
  alias Lux.Signal

  @type prompt :: Lux.LLM.Provider.prompt()
  @type tools :: Lux.LLM.Provider.tools()
  @type opts :: map() | keyword()

  @doc """
  Calls an LLM provider while measuring latency, normalizing token usage and cost,
  updating `Lux.Signal` metadata, and emitting `:telemetry` events.
  """
  @spec call(module() | atom() | function(), prompt(), tools(), opts()) ::
          {:ok, Signal.t()} | {:error, term()}
  def call(provider_or_spec, prompt, tools \\ [], opts \\ []) do
    opts_map = to_map(opts)
    model = Map.get(opts_map, :model, "unknown")
    provider_id = extract_provider_id(provider_or_spec, opts_map)

    telemetry_meta = %{
      provider: provider_id,
      model: model,
      prompt: prompt,
      tools: tools
    }

    start_time = System.monotonic_time()
    system_time = System.system_time()

    :telemetry.execute([:lux, :llm, :call, :start], %{system_time: system_time}, telemetry_meta)

    result = execute_call(provider_or_spec, prompt, tools, opts_map)

    stop_time = System.monotonic_time()
    duration_native = stop_time - start_time
    duration_ms = System.convert_time_unit(duration_native, :native, :millisecond)

    case result do
      {:ok, %Signal{} = signal} ->
        raw_usage = extract_raw_usage(signal)
        normalized_usage = normalize_usage(raw_usage)
        cost_map = calculate_cost(provider_id, model, normalized_usage.prompt_tokens, normalized_usage.completion_tokens, opts_map)

        telemetry_data = %{
          latency_ms: duration_ms,
          usage: normalized_usage,
          cost: cost_map
        }

        updated_metadata = Map.merge(signal.metadata || %{}, telemetry_data)
        updated_signal = %{signal | metadata: updated_metadata}

        stop_measurements = %{
          duration: duration_native,
          duration_ms: duration_ms,
          prompt_tokens: normalized_usage.prompt_tokens,
          completion_tokens: normalized_usage.completion_tokens,
          total_cost: cost_map.total_cost
        }

        stop_metadata = Map.merge(telemetry_meta, %{signal: updated_signal})
        :telemetry.execute([:lux, :llm, :call, :stop], stop_measurements, stop_metadata)

        {:ok, updated_signal}

      {:error, reason} ->
        exception_measurements = %{
          duration: duration_native,
          duration_ms: duration_ms
        }

        exception_metadata = Map.merge(telemetry_meta, %{reason: reason})
        :telemetry.execute([:lux, :llm, :call, :exception], exception_measurements, exception_metadata)

        {:error, reason}
    end
  end

  @doc """
  Instruments a custom zero-arity function block with start, stop, and exception telemetry events.
  """
  @spec instrument(map(), (-> {:ok, Signal.t()} | {:error, term()})) ::
          {:ok, Signal.t()} | {:error, term()}
  def instrument(metadata \\ %{}, fun) when is_function(fun, 0) do
    provider = Map.get(metadata, :provider, :unknown)
    model = Map.get(metadata, :model, "unknown")

    telemetry_meta = Map.merge(%{provider: provider, model: model}, metadata)

    start_time = System.monotonic_time()
    system_time = System.system_time()

    :telemetry.execute([:lux, :llm, :call, :start], %{system_time: system_time}, telemetry_meta)

    result =
      try do
        fun.()
      catch
        kind, reason ->
          stop_time = System.monotonic_time()
          duration_native = stop_time - start_time
          duration_ms = System.convert_time_unit(duration_native, :native, :millisecond)

          :telemetry.execute(
            [:lux, :llm, :call, :exception],
            %{duration: duration_native, duration_ms: duration_ms},
            Map.merge(telemetry_meta, %{kind: kind, reason: reason})
          )

          :erlang.raise(kind, reason, __STACKTRACE__)
      end

    stop_time = System.monotonic_time()
    duration_native = stop_time - start_time
    duration_ms = System.convert_time_unit(duration_native, :native, :millisecond)

    case result do
      {:ok, %Signal{} = signal} ->
        raw_usage = extract_raw_usage(signal)
        normalized_usage = normalize_usage(raw_usage)
        cost_map = calculate_cost(provider, model, normalized_usage.prompt_tokens, normalized_usage.completion_tokens, metadata)

        updated_metadata =
          Map.merge(signal.metadata || %{}, %{
            latency_ms: duration_ms,
            usage: normalized_usage,
            cost: cost_map
          })

        updated_signal = %{signal | metadata: updated_metadata}

        stop_measurements = %{
          duration: duration_native,
          duration_ms: duration_ms,
          prompt_tokens: normalized_usage.prompt_tokens,
          completion_tokens: normalized_usage.completion_tokens,
          total_cost: cost_map.total_cost
        }

        :telemetry.execute([:lux, :llm, :call, :stop], stop_measurements, Map.merge(telemetry_meta, %{signal: updated_signal}))
        {:ok, updated_signal}

      {:error, reason} ->
        :telemetry.execute(
          [:lux, :llm, :call, :exception],
          %{duration: duration_native, duration_ms: duration_ms},
          Map.merge(telemetry_meta, %{reason: reason})
        )

        {:error, reason}
    end
  end

  @prompt_keys [:prompt_tokens, "prompt_tokens", "promptTokenCount", "input_tokens", :input_tokens]
  @completion_keys [:completion_tokens, "completion_tokens", "candidatesTokenCount", "output_tokens", :output_tokens]
  @total_keys [:total_tokens, "total_tokens", "totalTokenCount"]

  @doc """
  Normalizes raw token usage maps from various provider response formats into standard atom-keyed maps.
  """
  @spec normalize_usage(term()) :: %{
          prompt_tokens: non_neg_integer(),
          completion_tokens: non_neg_integer(),
          total_tokens: non_neg_integer()
        }
  def normalize_usage(usage) when is_map(usage) do
    prompt = parse_integer(find_first_val(usage, @prompt_keys))
    completion = parse_integer(find_first_val(usage, @completion_keys))
    total = resolve_total(usage, prompt, completion)

    %{
      prompt_tokens: max(0, prompt),
      completion_tokens: max(0, completion),
      total_tokens: max(0, total)
    }
  end

  def normalize_usage(_), do: %{prompt_tokens: 0, completion_tokens: 0, total_tokens: 0}

  defp find_first_val(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp resolve_total(usage, prompt, completion) do
    case find_first_val(usage, @total_keys) do
      val when not is_nil(val) and val != "" -> parse_integer(val)
      _ -> prompt + completion
    end
  end

  defp parse_integer(val) when is_integer(val), do: val
  defp parse_integer(val) when is_float(val), do: trunc(val)
  defp parse_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _rest} ->
        int

      :error ->
        try do
          String.to_integer(val)
        rescue
          _ -> 0
        end
    end
  end
  defp parse_integer(_), do: 0

  @doc """
  Calculates prompt, completion, and total cost given model ID, prompt token count, completion token count, and options.
  """
  @spec calculate_cost(term(), String.t(), non_neg_integer(), non_neg_integer(), map() | keyword()) :: %{
          prompt_cost: float(),
          completion_cost: float(),
          total_cost: float()
        }
  def calculate_cost(provider_id, model_id, prompt_tokens, completion_tokens, opts \\ %{}) do
    opts_map = to_map(opts)
    reg = Map.get(opts_map, :registry_name, ProviderRegistry)

    pricing =
      if Map.has_key?(opts_map, :cost_per_1k_prompt_tokens) do
        {Map.get(opts_map, :cost_per_1k_prompt_tokens, 0.0), Map.get(opts_map, :cost_per_1k_completion_tokens, 0.0)}
      else
        lookup_model_pricing(provider_id, model_id, reg)
      end

    {prompt_rate, completion_rate} = pricing

    prompt_cost = (prompt_tokens / 1000.0) * prompt_rate
    completion_cost = (completion_tokens / 1000.0) * completion_rate
    total_cost = prompt_cost + completion_cost

    %{
      prompt_cost: prompt_cost,
      completion_cost: completion_cost,
      total_cost: total_cost
    }
  end

  # Helpers

  defp execute_call(fun, prompt, tools, _opts) when is_function(fun, 2) do
    fun.(prompt, tools)
  end

  defp execute_call(fun, prompt, tools, opts) when is_function(fun, 3) do
    fun.(prompt, tools, opts)
  end

  defp execute_call(Router, prompt, tools, opts) do
    Router.call(prompt, tools, opts)
  end

  defp execute_call(module, prompt, tools, opts) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :call, 3) do
      module.call(prompt, tools, Router.build_call_opts(opts))
    else
      Router.call(prompt, tools, Map.put_new(opts, :provider_id, module))
    end
  end

  defp extract_raw_usage(%Signal{metadata: metadata}) when is_map(metadata) do
    Map.get(metadata, :usage) || Map.get(metadata, "usage") || %{}
  end

  defp extract_raw_usage(_), do: %{}

  defp extract_provider_id(fun, _opts) when is_function(fun), do: :function

  defp extract_provider_id(module, _opts) when is_atom(module) do
    if function_exported?(module, :id, 0) do
      module.id()
    else
      module
    end
  end

  defp extract_provider_id(_spec, opts) do
    Map.get(opts, :provider_id, :unknown)
  end

  defp lookup_model_pricing(provider_id, model_id, registry_name) do
    try do
      filter_opts = [registry_name: registry_name, status: :active]

      filter_opts =
        if is_atom(provider_id) and provider_id not in [:unknown, :function] do
          Keyword.put(filter_opts, :provider_id, provider_id)
        else
          filter_opts
        end

      models = ProviderRegistry.list_models(filter_opts)

      case Enum.find(models, &(&1.id == model_id)) do
        %ModelConfig{} = model ->
          {model.cost_per_1k_prompt_tokens, model.cost_per_1k_completion_tokens}

        nil ->
          {0.0, 0.0}
      end
    catch
      _, _ -> {0.0, 0.0}
    end
  end

  defp to_map(opts) when is_map(opts), do: opts
  defp to_map(opts) when is_list(opts), do: Enum.into(opts, %{})
  defp to_map(_), do: %{}
end
