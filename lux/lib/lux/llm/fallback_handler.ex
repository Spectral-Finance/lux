defmodule Lux.LLM.FallbackHandler do
  @moduledoc """
  Intelligent fallback and retry handler for LLM requests across registered providers.
  """

  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.TelemetryAndCache

  @doc """
  Executes `prompt` against the selected primary provider and automatically falls back
  through secondary providers if an error occurs.
  """
  def execute_with_fallback(prompt, tools, opts, primary_selection) do
    fallback_chain = build_candidate_chain(primary_selection, opts)
    runner = Map.get(opts, :runner_fn)

    do_attempt(fallback_chain, prompt, tools, opts, runner, [])
  end

  defp do_attempt([], _prompt, _tools, _opts, _runner, errors) do
    {:error, {:all_providers_failed, Enum.reverse(errors)}}
  end

  defp do_attempt([candidate | rest], prompt, tools, opts, runner, errors) do
    start_us = System.monotonic_time(:microsecond)

    call_opts =
      opts
      |> Map.put(:model, candidate.model)
      |> Map.drop([:runner_fn, :fallback_providers, :required_capabilities, :optimize_for])

    result =
      if is_function(runner, 4) do
        runner.(candidate.provider_id, candidate.module, prompt, call_opts)
      else
        candidate.module.call(prompt, tools, call_opts)
      end

    latency_ms = max(0.0, (System.monotonic_time(:microsecond) - start_us) / 1_000.0)

    case result do
      {:ok, response} ->
        ProviderRegistry.update_status(candidate.provider_id, :healthy)

        TelemetryAndCache.record_call(%{
          provider_id: candidate.provider_id,
          model: candidate.model,
          latency_ms: latency_ms,
          success: true,
          input_tokens: estimate_tokens(prompt),
          output_tokens: extract_output_tokens(response),
          metadata: candidate.metadata
        })

        {:ok, enrich_response(response, candidate)}

      {:error, reason} ->
        ProviderRegistry.update_status(candidate.provider_id, :degraded)

        TelemetryAndCache.record_call(%{
          provider_id: candidate.provider_id,
          model: candidate.model,
          latency_ms: latency_ms,
          success: false,
          input_tokens: estimate_tokens(prompt),
          output_tokens: 0,
          metadata: candidate.metadata
        })

        do_attempt(
          rest,
          prompt,
          tools,
          opts,
          runner,
          [{candidate.provider_id, candidate.model, reason} | errors]
        )
    end
  end

  defp build_candidate_chain(primary, opts) do
    fallback_ids =
      Map.get(opts, :fallback_providers) ||
        ProviderRegistry.list_providers()
        |> Enum.map(& &1.id)
        |> Enum.reject(&(&1 == primary.provider_id))

    fallbacks =
      Enum.flat_map(fallback_ids, fn provider_id ->
        case ProviderRegistry.get_provider(provider_id) do
          {:ok, %{status: status, module: mod, models: models}} when status != :unhealthy ->
            case Enum.at(models, 0) do
              {model_name, meta} ->
                [%{provider_id: provider_id, module: mod, model: model_name, metadata: meta}]

              nil ->
                []
            end

          _ ->
            []
        end
      end)

    [primary | fallbacks]
  end

  defp enrich_response(%Lux.LLM.Response{} = resp, candidate) do
    %{resp | provider: candidate.provider_id, model: candidate.model}
  end

  defp enrich_response(other, _candidate), do: other

  defp estimate_tokens(text) when is_binary(text), do: max(1, div(String.length(text), 4))
  defp estimate_tokens(_), do: 1

  defp extract_output_tokens(%Lux.LLM.Response{content: content}) when is_binary(content) do
    max(1, div(String.length(content), 4))
  end

  defp extract_output_tokens(_), do: 0
end
