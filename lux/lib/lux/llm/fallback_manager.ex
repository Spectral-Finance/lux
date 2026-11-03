defmodule Lux.LLM.FallbackManager do
  @moduledoc """
  Intelligent fallback orchestrator and circuit breaker for LLM invocations.

  If a provider call fails due to rate limits (HTTP 429), timeouts, service outages (5xx),
  or connection failures, the FallbackManager automatically intercepts the error,
  records the incident, and gracefully attempts downstream alternative providers.
  """

  require Logger

  alias Lux.LLM.Registry
  alias Lux.LLM.Response

  @doc """
  Executes an LLM call across a prioritized fallback chain of providers.

  ## Parameters
  - `prompt`: String prompt text
  - `tools`: Tools available to the model
  - `options`: Execution options including `:fallback_chain` or default chain
  """
  @spec execute_with_fallback(String.t(), list(), map() | keyword()) ::
          {:ok, Response.t(), map()} | {:error, term(), list()}
  def execute_with_fallback(prompt, tools, options \\ %{}) do
    chain = resolve_chain(options)
    do_fallback_loop(chain, prompt, tools, options, [])
  end

  defp resolve_chain(opts) do
    explicit = get_opt(opts, :fallback_chain, nil)

    if explicit && is_list(explicit) && explicit != [] do
      explicit
    else
      Registry.list_enabled_providers()
      |> Enum.map(& &1.id)
    end
  end

  defp do_fallback_loop([], _prompt, _tools, _opts, attempts) do
    Logger.error("[Lux.LLM.FallbackManager] All providers in fallback chain exhausted.")
    {:error, "All providers failed in fallback chain", Enum.reverse(attempts)}
  end

  defp do_fallback_loop([provider_id | rest], prompt, tools, opts, attempts) do
    case Registry.get_provider(provider_id) do
      {:ok, provider} ->
        Logger.info("[Lux.LLM.FallbackManager] Attempting provider: #{provider.name}")

        case invoke_provider(provider.module, prompt, tools, opts) do
          {:ok, %Response{} = resp} ->
            meta = %{
              successful_provider: provider.id,
              attempts_count: length(attempts) + 1,
              fallback_history: Enum.reverse(attempts)
            }

            {:ok, resp, meta}

          {:error, reason} ->
            Logger.warning(
              "[Lux.LLM.FallbackManager] Provider #{provider.id} failed: #{inspect(reason)}. Falling back..."
            )

            attempt_record = %{
              provider: provider.id,
              reason: inspect(reason),
              timestamp: System.system_time(:second)
            }

            do_fallback_loop(rest, prompt, tools, opts, [attempt_record | attempts])
        end

      {:error, :not_found} ->
        do_fallback_loop(rest, prompt, tools, opts, [
          %{provider: provider_id, reason: :not_found} | attempts
        ])
    end
  end

  defp invoke_provider(module, prompt, tools, opts) do
    try do
      if function_exported?(module, :call, 3) do
        module.call(prompt, tools, opts)
      else
        {:error, :unsupported_provider_module}
      end
    catch
      kind, err ->
        {:error, {kind, err}}
    end
  end

  defp get_opt(opts, key, default) when is_map(opts) do
    Map.get(opts, key) || Map.get(opts, to_string(key), default)
  end

  defp get_opt(opts, key, default) when is_list(opts) do
    Keyword.get(opts, key, default)
  end
end
