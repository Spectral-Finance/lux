defmodule Lux.LLM.Selector do
  @moduledoc """
  Automatic model selection and smart fallback handling.
  Chooses the best provider based on task type, cost, and availability.
  """
  alias Lux.LLM.ProviderRegistry

  def select(task_type \\\\ :general, opts \\\\ []) do
    providers = ProviderRegistry.available()
    preferred = opts[:preferred] || Application.get_env(:lux, :preferred_provider)

    providers
    |> Enum.filter(fn p -> matches_task?(p, task_type) end)
    |> Enum.sort_by(& &1.priority, :desc)
    |> case do
      [] -> {:error, "No available provider for task type: #{task_type}"}
      available -> {:ok, hd(available), tl(available)}
    end
  end

  def call_with_fallback(prompt, tools, options) do
    task_type = options[:task_type] || :general
    case select(task_type, options) do
      {:ok, primary, fallbacks} ->
        try_provider(primary, prompt, tools, options, fallbacks)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp try_provider(provider, prompt, tools, options, fallbacks) do
    case provider.module.call(prompt, tools, options) do
      {:ok, response} -> {:ok, response, provider.name}
      {:error, _reason} when fallbacks != [] ->
        [next | rest] = fallbacks
        try_provider(next, prompt, tools, options, rest)
      {:error, reason} ->
        {:error, "All providers failed. Last error: #{reason}"}
    end
  end

  defp matches_task?(provider, :general), do: true
  defp matches_task?(provider, :code), do: provider.name != :mira
  defp matches_task?(provider, :creative), do: provider.name != :openai
  defp matches_task?(provider, :fast), do: provider.priority >= 0
  defp matches_task?(_, _), do: true
end