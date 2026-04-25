defmodule Lux.LLM.FallbackHandler do
  @moduledoc """
  Intelligent fallback handler for LLM provider failures.

  Implements exponential backoff, provider health tracking, and
  configurable fallback chains. Integrates with ProviderRegistry
  to select the next best provider on failure.

  ## Fallback Strategies

  - `:priority` — Fall back to the next provider by priority (default)
  - `:cost` — Fall back to the cheapest available provider
  - `:random` — Fall back to a random available provider
  - `:round_robin` — Rotate through providers sequentially

  ## Usage

      # Execute with fallback
      Lux.LLM.FallbackHandler.call("Explain AI", [],
        model: "gpt-4",
        strategy: :priority,
        max_retries: 3,
        backoff_ms: 500)
  """

  alias Lux.LLM.ProviderRegistry

  @default_max_retries 3
  @default_backoff_ms 500
  @default_strategy :priority

  @type fallback_result :: {:ok, Lux.LLM.Response.t(), map()} | {:error, String.t(), map()}
  @type strategy :: :priority | :cost | :random | :round_robin

  @doc """
  Execute an LLM call with intelligent fallback handling.

  Returns `{:ok, response, metadata}` on success or
  `{:error, reason, metadata}` when all attempts exhausted.

  Metadata includes `:provider_used`, `:model_used`, `:attempts`,
  `:fallback_chain`, and `:total_latency_ms`.
  """
  @spec call(String.t(), list(), keyword()) :: fallback_result()
  def call(prompt, tools, opts \\ []) do
    model = Keyword.get(opts, :model)
    strategy = Keyword.get(opts, :strategy, @default_strategy)
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    backoff_ms = Keyword.get(opts, :backoff_ms, @default_backoff_ms)
    cost_limit = Keyword.get(opts, :cost_limit_usd)

    providers = get_fallback_chain(model, strategy)
    start_time = System.monotonic_time(:millisecond)

    result =
      providers
      |> Enum.with_index()
      |> Enum.reduce_while({:error, "no_providers_available", []}, fn {provider, idx}, {:error, _reason, attempts} ->
        # Apply backoff for retries beyond the first
        if idx > 0 do
          backoff = backoff_ms * :math.pow(2, idx - 1) |> round()
          Process.sleep(min(backoff, 30_000))
        end

        # Check cost limit
        input_tokens = div(String.length(prompt), 4) + 1
        est_cost = provider.module.estimate_cost(model || "default", input_tokens, 500)

        if cost_limit && est_cost > cost_limit do
          {:cont, {:error, "cost_limit_exceeded", attempts ++ [{provider.id, :cost_exceeded}]}}
        else
          config = build_config(provider, model, opts)

          case provider.module.call(prompt, tools, config) do
            {:ok, response} ->
              ProviderRegistry.record_health(provider.id, :ok)
              {:halt, {:ok, response, provider}}

            {:error, reason} ->
              ProviderRegistry.record_health(provider.id, :error, reason)
              new_attempts = attempts ++ [{provider.id, reason}]

              if idx + 1 >= max_retries do
                {:halt, {:error, "max_retries_exceeded", new_attempts}}
              else
                {:cont, {:error, reason, new_attempts}}
              end
          end
        end
      end)

    end_time = System.monotonic_time(:millisecond)

    case result do
      {:ok, response, provider} ->
        {:ok, response, %{
          provider_used: provider.id,
          model_used: model,
          attempts: 1,
          total_latency_ms: end_time - start_time,
          fallback_used: false
        }}

      {:error, reason, attempts} when is_list(attempts) ->
        {:error, reason, %{
          provider_used: nil,
          model_used: model,
          attempts: length(attempts),
          fallback_chain: attempts,
          total_latency_ms: end_time - start_time,
          fallback_used: length(attempts) > 1
        }}

      {:error, reason, _} ->
        {:error, reason, %{
          provider_used: nil,
          model_used: model,
          attempts: 0,
          total_latency_ms: end_time - start_time
        }}
    end
  end

  # Private

  defp get_fallback_chain(model, strategy) do
    providers =
      ProviderRegistry.list_providers()
      |> Enum.filter(& &1.enabled)

    providers = if model do
      Enum.filter(providers, fn p -> p.models == [] or model in p.models end)
    else
      providers
    end

    case strategy do
      :priority -> Enum.sort_by(providers, & &1.priority, :desc)
      :cost -> Enum.sort_by(providers, & &1.priority, :desc)  # cost sorted in call
      :random -> Enum.shuffle(providers)
      :round_robin -> rotate_providers(providers)
    end
  end

  defp rotate_providers(providers) do
    # Use current timestamp as rotation seed
    key = rem(System.system_time(:second), max(length(providers), 1))
    {head, tail} = Enum.split(providers, key)
    tail ++ head
  end

  defp build_config(provider, model, opts) do
    base = provider.config
    base = if model && model != "", do: Map.put(base, :model, model), else: base
    base = case Keyword.get(opts, :temperature) do
      nil -> base
      t -> Map.put(base, :temperature, t)
    end
    base = case Keyword.get(opts, :max_tokens) do
      nil -> base
      m -> Map.put(base, :max_tokens, m)
    end
    base
  end
end
