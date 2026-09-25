defmodule Lux.LLM.Selection do
  @moduledoc """
  High‑level helper for selecting a provider, invoking it, and handling
  fall‑backs, cost tracking and telemetry.

  The default selection strategy is very simple – it picks the first
  configured provider.  The module is deliberately extensible; more
  sophisticated strategies (cost‑aware, latency‑aware, etc.) can be added
  later without changing the public API.
  """

  @fallback_order [:anthropic, :openai]

  @doc """
  Generates a completion using the best available provider.

  Options:

    * `:fallback` – a list of provider names (atoms) to try if the primary
      provider fails.  Defaults to `@fallback_order`.
  """
  @spec generate(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate(prompt, opts \\ []) when is_binary(prompt) do
    provider = select_provider(opts)

    case provider do
      nil -> {:error, :no_providers_configured}
      mod -> invoke_provider(mod, prompt, opts)
    end
  end

  @doc """
  Returns the provider module that would be used for the given options.
  """
  @spec select_provider(keyword()) :: module() | nil
  def select_provider(_opts) do
    # Simple strategy: first provider in the registry list
    Lux.LLM.ProviderRegistry.list_providers()
    |> List.first()
  end

  ## Internal

  defp invoke_provider(provider, prompt, opts) do
    start = System.monotonic_time()
    result = provider.generate(prompt, opts)

    case result do
      {:ok, response} = ok ->
        duration = System.monotonic_time() - start
        cost = provider.cost(response)

        :telemetry.execute(
          [:lux, :llm, :request],
          %{duration: duration, cost: cost},
          %{provider: provider.name()}
        )

        ok

      {:error, _reason} = err ->
        # attempt fall‑back providers
        fallback(provider, prompt, opts, err)
    end
  end

  defp fallback(failed_provider, prompt, opts, _original_error) do
    fallback_list = Keyword.get(opts, :fallback, @fallback_order) -- [failed_provider.name()]

    Enum.find_value(fallback_list, fn name ->
      case Lux.LLM.ProviderRegistry.get_provider(name) do
        nil -> nil
        mod ->
          case mod.generate(prompt, opts) do
            {:ok, _} = ok -> ok
            _ -> nil
          end
      end
    end) || {:error, :all_providers_failed}
  end
end
