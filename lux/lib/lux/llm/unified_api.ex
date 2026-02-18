defmodule Lux.LLM.UnifiedAPI do
  @moduledoc """
  Unified API for chat completions and model selection using Lux.
  """

  import Lux.HTTP
  import Jason
  import Plug.Conn

  @base_url "https://api.openrouter.com/v1"

  defp request(method, endpoint, params \\ %{}) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer YOUR_API_KEY"}
    ]

    HTTP.request(method, "#{@base_url}#{endpoint}", params, headers)
  end

  @doc """
  Generates text using the OpenRouter LLM.

  ## Parameters
  - `prompt`: The input prompt for the model.
  - `max_tokens`: Maximum number of tokens to generate (default: 50).

  ## Returns
  - A tuple with {:ok, response} or {:error, reason}
  """
  def generate_text(prompt, max_tokens \\ 50) do
    params = %{
      "prompt" => prompt,
      "max_tokens" => max_tokens
    }

    request(:post, "/completions", params)
  end

  @doc """
  Selects a model and generates text.

  ## Parameters
  - `model`: The model to use.
  - `prompt`: The input prompt for the model.
  - `max_tokens`: Maximum number of tokens to generate (default: 50).

  ## Returns
  - A tuple with {:ok, response} or {:error, reason}
  """
  def select_model_and_generate(model, prompt, max_tokens \\ 50) when is_binary(model) do
    params = %{
      "model" => model,
      "prompt" => prompt,
      "max_tokens" => max_tokens
    }

    request(:post, "/completions", params)
  end

  @behaviour Lux.LLM

  def generate(model, prompt, max_tokens \\ 50) when is_binary(model) do
    select_model_and_generate(model, prompt, max_tokens)
  end
end

def select_models(criteria) do
  params = %{
    "criteria" => criteria
  }

  request(:post, "/models", params)
end