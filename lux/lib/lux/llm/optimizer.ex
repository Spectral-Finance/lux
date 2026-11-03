defmodule Lux.LLM.Optimizer do
  @moduledoc """
  Prompt optimization and token caching helpers:
  - Normalizes prompts and trims whitespace redundancy
  - Generates deterministic cache keys for prompt caching
  - Estimates token requirements
  """

  @doc """
  Minifies and optimizes prompt text by removing excess whitespace and redundant empty lines.
  """
  @spec optimize_prompt(String.t()) :: String.t()
  def optimize_prompt(text) when is_binary(text) do
    text
    |> String.replace(~r/[ \t]+/, " ")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  def optimize_prompt(text), do: text

  @doc """
  Generates deterministic SHA-256 cache key for prompt caching.
  """
  @spec cache_key(String.t(), String.t()) :: String.t()
  def cache_key(system_prompt, user_prompt) do
    payload = optimize_prompt(system_prompt) <> ":::" <> optimize_prompt(user_prompt)
    :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
  end

  @doc """
  Estimates token count (~4 characters per token heuristic).
  """
  @spec estimate_tokens(String.t()) :: non_neg_integer()
  def estimate_tokens(text) when is_binary(text) do
    max(div(String.length(text), 4), 1)
  end

  def estimate_tokens(_), do: 0
end
