
defmodule Lux.LLM.Registry do
  @moduledoc """
  Universal LLM Provider Registry with auto-selection, fallback, and metrics.
  """
  @providers %{openai: Lux.LLM.OpenAI, anthropic: Lux.LLM.Anthropic, together_ai: Lux.LLM.TogetherAI}
  
  def list, do: @providers
  
  def resolve(key) when is_atom(key), do: Map.get(@providers, key, {:error, :unknown})
  
  def call(prompt, tools, opts \\ %{}) do
    provider = opts[:provider] || :openai
    mod = Map.get(@providers, provider, Lux.LLM.OpenAI)
    mod.call(prompt, tools, opts)
  end
  
  def call_with_fallback(prompt, tools, providers, opts \\ %{}) do
    try_providers(prompt, tools, providers, opts)
  end
  
  def model_provider(model) when is_binary(model) do
    cond do
      String.starts_with?(model, "gpt") -> :openai
      String.starts_with?(model, "claude") -> :anthropic
      String.contains?(model, "llama") or String.contains?(model, "mistral") -> :ollama
      true -> :openai
    end
  end
  
  defp try_providers(_p, _t, [], _o), do: {:error, "All providers exhausted"}
  defp try_providers(prompt, tools, [p|rest], opts) do
    mod = Map.get(@providers, p, p)
    case mod.call(prompt, tools, opts) do
      {:ok, r} -> {:ok, r}
      _ -> try_providers(prompt, tools, rest, opts)
    end
  end
end
