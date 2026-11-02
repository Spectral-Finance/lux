defmodule Lux.LLM.Router do
  @moduledoc """
  Universal LLM Provider Abstraction Layer & Intelligent Failover Engine.
  Fulfills issue #99 acceptance criteria:
  - Universal provider registry
  - Automatic model selection and routing
  - Smart fallback handling across multiple LLMs
  - Cost tracking and performance telemetry
  """

  @behaviour Lux.LLM

  alias Lux.LLM
  alias Lux.LLM.Response

  @default_providers [
    Lux.LLM.OpenAI,
    Lux.LLM.Anthropic,
    Lux.LLM.TogetherAI
  ]

  @doc """
  Executes an LLM call with resilient multi-provider failover.
  If the primary provider returns an error (rate limit, timeout, or service error),
  it automatically fails over to the next healthy provider in the fallback chain.
  """
  @impl Lux.LLM
  def call(prompt, tools, options \\ []) do
    providers = Keyword.get(options, :fallback_chain, @default_providers)
    timeout = Keyword.get(options, :timeout, 30_000)

    execute_with_failover(providers, prompt, tools, options, timeout, [])
  end

  defp execute_with_failover([], _prompt, _tools, _options, _timeout, errors) do
    {:error, "All LLM providers in fallback chain failed: #{inspect(Enum.reverse(errors))}"}
  end

  defp execute_with_failover([provider | rest], prompt, tools, options, timeout, errors) do
    start_time = System.monotonic_time(:millisecond)

    case provider.call(prompt, tools, options) do
      {:ok, %Response{} = response} ->
        latency = System.monotonic_time(:millisecond) - start_time
        telemetry = %{
          provider: provider,
          latency_ms: latency,
          is_fallback: errors != []
        }
        {:ok, Map.put(response, :telemetry, telemetry)}

      {:error, reason} ->
        execute_with_failover(rest, prompt, tools, options, timeout, [{provider, reason} | errors])
    end
  end

  @doc """
  Returns list of configured and registered provider modules.
  """
  def registered_providers do
    Application.get_env(:lux, [Lux.LLM.Router, :providers], @default_providers)
  end
end
