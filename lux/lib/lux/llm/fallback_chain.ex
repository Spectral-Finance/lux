defmodule Lux.LLM.FallbackChain do
  @moduledoc """
  Intelligent fallback orchestrator:
  - Cascades execution across a priority chain of LLM providers
  - Traps transient network, rate limit (429), or 5xx provider failures and fails over seamlessly
  """

  @default_chain [:openai, :anthropic, :together_ai, :groq]

  @doc """
  Executes an LLM function through a fallback cascade.
  Takes a list of provider candidates and an execution lambda `(provider -> {:ok, result} | {:error, reason})`.
  """
  @spec execute(list(atom()), (atom() -> {:ok, term()} | {:error, term()})) ::
          {:ok, term(), atom(), list(map())} | {:error, :all_providers_failed, list(map())}
  def execute(chain \\ @default_chain, exec_fn) when is_function(exec_fn, 1) do
    do_execute(chain, exec_fn, [])
  end

  defp do_execute([], _exec_fn, attempts) do
    {:error, :all_providers_failed, Enum.reverse(attempts)}
  end

  defp do_execute([provider | rest], exec_fn, attempts) do
    case exec_fn.(provider) do
      {:ok, result} ->
        attempt_record = %{provider: provider, status: :success}
        {:ok, result, provider, Enum.reverse([attempt_record | attempts])}

      {:error, reason} ->
        attempt_record = %{provider: provider, status: :failed, reason: reason}
        do_execute(rest, exec_fn, [attempt_record | attempts])
    end
  end
end
