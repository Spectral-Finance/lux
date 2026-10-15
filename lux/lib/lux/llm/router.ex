defmodule Lux.LLM.Router do
  @moduledoc """
  Universal LLM router orchestrating automatic model selection, intelligent
  provider fallback chains, response caching, and cost/latency telemetry.
  """

  @behaviour Lux.LLM

  alias Lux.LLM.Cache
  alias Lux.LLM.ModelSelector
  alias Lux.LLM.Provider
  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.Response
  alias Lux.LLM.Telemetry

  require Logger

  @doc """
  Routes an LLM request through cache lookup, automatic model selection,
  provider execution, fallback chain recovery, and telemetry recording.
  """
  @impl true
  @spec call(String.t() | [map()], list(), map() | keyword()) ::
          {:ok, term()} | {:error, term()}
  def call(prompt, tools \\ [], options \\ %{}) do
    config = normalize_options(options)

    case build_candidates(prompt, tools, config) do
      [] ->
        {:error, :no_available_providers}

      [primary | _] = candidates ->
        execute_with_cache(prompt, tools, config, primary, candidates)
    end
  end

  @doc """
  Builds the ordered list of candidate `{provider, module, model}` targets
  for a request, including configured fallback providers.
  """
  @spec build_candidates(term(), list(), map()) :: [map()]
  def build_candidates(prompt, tools, config) when is_map(config) do
    if is_atom(config[:provider]) and not is_nil(config[:provider]) do
      build_explicit_provider_chain(prompt, tools, config)
    else
      build_auto_selected_chain(prompt, tools, config)
    end
  end

  defp execute_with_cache(prompt, tools, config, primary, candidates) do
    cache_enabled = Map.get(config, :cache, false)

    if cache_enabled do
      cache_config =
        config
        |> Map.put_new(:provider, primary.provider)
        |> Map.put_new(:model, primary.model)

      cache_key = Cache.build_key(prompt, tools, cache_config)

      case Cache.get(cache_key) do
        {:ok, cached_response} ->
          Telemetry.record_request(primary.provider, primary.model, %{
            status: :ok,
            latency_ms: 0,
            prompt_tokens: 0,
            completion_tokens: 0,
            cost_usd: 0.0,
            cache_hit: true,
            fallback: false
          })

          maybe_normalize({:ok, cached_response}, primary.provider, config)

        :miss ->
          result = execute_fallback_chain(prompt, tools, config, candidates, false, [])
          maybe_store_cache(cache_key, result, config)
          result
      end
    else
      execute_fallback_chain(prompt, tools, config, candidates, false, [])
    end
  end

  defp maybe_store_cache(cache_key, {:ok, response}, config) do
    ttl_ms = Map.get(config, :cache_ttl_ms, 300_000)
    Cache.put(cache_key, response, ttl_ms: ttl_ms)
  end

  defp maybe_store_cache(_cache_key, _error, _config), do: :ok

  defp execute_fallback_chain(_prompt, _tools, config, [], _is_fallback, errors) do
    reversed = Enum.reverse(errors)

    case {reversed, Map.get(config, :fallback_enabled, true)} do
      {[{_provider, single_error}], false} ->
        {:error, single_error}

      _ ->
        {:error, {:all_providers_failed, reversed}}
    end
  end

  defp execute_fallback_chain(
         prompt,
         tools,
         config,
         [candidate | rest],
         is_fallback,
         errors
       ) do
    retries = Map.get(config, :retry_attempts, 0)
    backoff_ms = Map.get(config, :retry_backoff_ms, 0)

    case invoke_with_retries(
           prompt,
           tools,
           config,
           candidate,
           retries,
           backoff_ms,
           is_fallback
         ) do
      {:ok, _response} = success ->
        maybe_normalize(success, candidate.provider, config)

      {:error, reason} ->
        if Map.get(config, :fallback_enabled, true) and rest != [] do
          Logger.warning(
            "LLM provider #{candidate.provider} (#{candidate.model}) failed: " <>
              "#{inspect(reason)}, falling back"
          )

          execute_fallback_chain(
            prompt,
            tools,
            config,
            rest,
            true,
            [{candidate.provider, reason} | errors]
          )
        else
          finalize_error(candidate.provider, reason, errors, config)
        end
    end
  end

  defp finalize_error(_provider, reason, [], %{fallback_enabled: false}) do
    {:error, reason}
  end

  defp finalize_error(_provider, reason, [], _config) do
    {:error, reason}
  end

  defp finalize_error(provider, reason, prior_errors, _config) do
    {:error, {:all_providers_failed, Enum.reverse([{provider, reason} | prior_errors])}}
  end

  defp invoke_with_retries(
         prompt,
         tools,
         config,
         candidate,
         retries_left,
         backoff_ms,
         is_fallback
       ) do
    start_ms = System.monotonic_time(:millisecond)
    provider_config = build_provider_config(config, candidate)

    result =
      try do
        candidate.module.call(prompt, tools, provider_config)
      rescue
        exception ->
          {:error, Exception.message(exception)}
      end

    latency_ms = max(0, System.monotonic_time(:millisecond) - start_ms)

    case result do
      {:ok, response} ->
        ProviderRegistry.mark_success(candidate.provider)
        record_success_telemetry(prompt, response, candidate, latency_ms, is_fallback)
        {:ok, response}

      {:error, reason} ->
        if retries_left > 0 do
          if backoff_ms > 0, do: Process.sleep(backoff_ms)

          invoke_with_retries(
            prompt,
            tools,
            config,
            candidate,
            retries_left - 1,
            backoff_ms,
            is_fallback
          )
        else
          ProviderRegistry.mark_failure(candidate.provider, reason)

          Telemetry.record_request(candidate.provider, candidate.model, %{
            status: :error,
            latency_ms: latency_ms,
            prompt_tokens: Telemetry.estimate_tokens(prompt),
            completion_tokens: 0,
            cost_usd: 0.0,
            cache_hit: false,
            fallback: is_fallback,
            error: reason
          })

          {:error, reason}
        end
    end
  end

  defp record_success_telemetry(prompt, response, candidate, latency_ms, is_fallback) do
    usage = Provider.extract_usage(response)

    prompt_tokens =
      if usage.prompt_tokens > 0,
        do: usage.prompt_tokens,
        else: Telemetry.estimate_tokens(prompt)

    completion_tokens =
      if usage.completion_tokens > 0,
        do: usage.completion_tokens,
        else: estimate_response_tokens(response)

    Telemetry.record_request(candidate.provider, candidate.model, %{
      status: :ok,
      latency_ms: latency_ms,
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      cache_hit: false,
      fallback: is_fallback
    })
  end

  defp estimate_response_tokens(%Response{content: content}) when is_binary(content) do
    Telemetry.estimate_tokens(content)
  end

  defp estimate_response_tokens(%{payload: %{content: content}}) do
    Telemetry.estimate_tokens(content)
  end

  defp estimate_response_tokens(other), do: Telemetry.estimate_tokens(other)

  defp build_provider_config(config, %{model: model, spec: spec, provider: provider_id}) do
    provider_overrides =
      config
      |> Map.get(:provider_configs, %{})
      |> Map.get(provider_id, %{})

    config
    |> Map.drop([
      :provider,
      :providers,
      :fallback_providers,
      :fallback_enabled,
      :strategy,
      :complexity,
      :required_capabilities,
      :min_context_window,
      :max_cost_per_1k,
      :cache,
      :cache_ttl_ms,
      :retry_attempts,
      :retry_backoff_ms,
      :normalize_response,
      :provider_configs,
      :auto_select
    ])
    |> Map.merge(spec.default_config || %{})
    |> Map.merge(provider_overrides)
    |> Map.put(:model, model)
  end

  defp build_explicit_provider_chain(prompt, tools, config) do
    primary_id = config[:provider]
    fallbacks = List.wrap(config[:fallback_providers])
    provider_ids = Enum.uniq([primary_id | fallbacks])

    Enum.flat_map(provider_ids, fn provider_id ->
      case ProviderRegistry.get_provider(provider_id) do
        {:ok, spec} ->
          if ProviderRegistry.healthy?(provider_id) do
            [select_model_for_provider(spec, prompt, tools, config, provider_id == primary_id)]
          else
            []
          end

        {:error, :not_found} ->
          []
      end
    end)
  end

  defp select_model_for_provider(spec, prompt, tools, config, is_primary) do
    explicit_model = if is_primary, do: Map.get(config, :model), else: nil

    cond do
      is_binary(explicit_model) ->
        %{
          provider: spec.id,
          module: spec.module,
          model: explicit_model,
          spec: spec
        }

      Map.has_key?(config, :strategy) ->
        sub_opts = Map.put(Map.delete(config, :model), :providers, [spec.id])

        case ModelSelector.select(prompt, tools, sub_opts) do
          {:ok, selection} ->
            selection

          {:error, _} ->
            %{
              provider: spec.id,
              module: spec.module,
              model: spec.default_model,
              spec: spec
            }
        end

      true ->
        %{
          provider: spec.id,
          module: spec.module,
          model: spec.default_model,
          spec: spec
        }
    end
  end

  defp build_auto_selected_chain(prompt, tools, config) do
    candidates = ModelSelector.rank_candidates(prompt, tools, config)

    if Map.get(config, :distinct_provider_fallback, true) do
      Enum.uniq_by(candidates, & &1.provider)
    else
      candidates
    end
  end

  defp maybe_normalize(result, provider_id, %{normalize_response: true}) do
    Provider.normalize_response(result, provider_id)
  end

  defp maybe_normalize(result, _provider_id, _config), do: result

  defp normalize_options(options) when is_map(options), do: options
  defp normalize_options(options) when is_list(options), do: Map.new(options)
end
