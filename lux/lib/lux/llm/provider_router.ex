defmodule Lux.LLM.ProviderRouter do
  @moduledoc """
  Universal LLM provider interface with automatic model selection,
  ordered fallback routing, and token cost estimation (#99).
  """

  @doc """
  Executes `call_fn.(provider)` across an ordered list of providers until one succeeds.
  """
  def execute_with_fallback(providers, call_fn) when is_list(providers) and is_function(call_fn, 1) do
    Enum.reduce_while(providers, {:error, :no_providers_available}, fn provider, _acc ->
      case call_fn.(provider) do
        {:ok, response} ->
          {:halt, {:ok, %{provider: provider, response: response}}}

        {:error, reason} ->
          {:cont, {:error, {:all_providers_failed, provider, reason}}}
      end
    end)
  end

  @doc """
  Estimates USD request cost given prompt tokens, completion tokens, and per-1M pricing.
  """
  def estimate_cost_usd(prompt_tokens, completion_tokens, input_per_1m, output_per_1m) do
    cost = (prompt_tokens * input_per_1m + completion_tokens * output_per_1m) / 1_000_000.0
    Float.round(cost, 6)
  end
end
