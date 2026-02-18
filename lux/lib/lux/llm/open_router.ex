defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  Implementation of OpenRouter Large Language Model (LLM) using Lux.
  """

  import Lux.HTTP
  import Jason
  import Plug.Conn
  import System

  @base_url "https://api.openrouter.com/v1"

  defp request(method, endpoint, params \\ %{}) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer System.get_env(\"OPEN_ROUTER_API_KEY\")"}
    ]
    |> Enum.filter(fn {key, _value} -> key in ["HTTP-Referer", "X-Title"] end)

    HTTP.request(method, "#{@base_url}#{endpoint}", params, headers)

  end


# Add configuration for OpenRouter API key and supported models in lux/config/open_router.exs

defmodule Lux.Config.OpenRouter do

  @moduledoc """

  Configuration module for OpenRouter.

  """


  def config do

    [

      api_key: System.get_env("OPEN_ROUTER_API_KEY"),

      supported_models: ["model1", "model2"]

    ]

  end

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

  @behaviour Lux.LLM

  def generate(model, prompt, max_tokens \\ 50) when is_binary(model) do
    generate_text(prompt, max_tokens)
  end
end

@doc """
  Handles HTTP-Referer and X-Title headers in requests.

  ## Parameters
  - `headers`: A map of headers to include in the request.
  - `endpoint`: The endpoint to send the request to.
  - `params`: Optional parameters for the request (default: %{}).

  ## Returns
  - A tuple with {:ok, response} or {:error, reason}
  """
  def handle_headers(headers, endpoint, params \\ %{}) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer System.get_env("OPEN_ROUTER_API_KEY")"}
      | Enum.filter(headers, fn {key, _value} -> key in ["HTTP-Referer", "X-Title"] end)
    ]

    request(:post, endpoint, params, headers)
  end
end

# Lines 1-98 of lux/lib/lux/llm/open_router.ex
defmodule Lux.LLM.OpenRouter do
  @moduledoc """
  Implementation of OpenRouter Large Language Model (LLM) using Lux.
  """

  import Lux.HTTP
  import Jason
  import Plug.Conn

  @base_url "https://api.openrouter.com/v1"

  defp request(method, endpoint, params \\ %{}) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer System.get_env(\"OPEN_ROUTER_API_KEY\")"}
    ]

{"Authorization", "Bearer System.get_env("OPEN_ROUTER_API_KEY")"}

    ]

    HTTP.request(method, "#{@base_url}#{endpoint}", params, headers)

  end


# Add configuration for OpenRouter API key and supported models in lux/config/open_router.exs

defmodule Lux.Config.OpenRouter do

  @moduledoc """

  Configuration module for OpenRouter.

  """


  def config do

    [

      api_key: System.get_env("OPEN_ROUTER_API_KEY"),

      supported_models: ["model1", "model2"]

    ]

  end

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

  @behaviour Lux.LLM

  def generate(model, prompt, max_tokens \\ 50) when is_binary(model) do
    generate_text(prompt, max_tokens)
  end
end

@doc """
  Handles HTTP-Referer and X-Title headers in requests.

  ## Parameters
  - `headers`: A map of headers to include in the request.
  - `endpoint`: The endpoint to send the request to.
  - `params`: Optional parameters for the request (default: %{}).

  ## Returns
  - A tuple with {:ok, response} or {:error, reason}
  """
  def handle_headers(headers, endpoint, params \\ %{}) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer System.get_env("OPEN_ROUTER_API_KEY")"}
      | Enum.filter(headers, fn {key, _value} -> key in ["HTTP-Referer", "X-Title"] end)
    ]

    request(:post, endpoint, params, headers)
  end
end

# Add integration tests for OpenRouter functionality
defmodule Lux.LLM.OpenRouterTest do
  use ExUnit.Case, async: true
  import Lux.HTTP

  @base_url "https://api.openrouter.com/v1"

  test "generates text using the OpenRouter LLM" do
    response = Lux.LLM.OpenRouter.generate_text("Hello, world!", 50)
    assert {:ok, _} = response
  end

  test "handles HTTP-Referer and X-Title headers in requests" do
    headers = %{"HTTP-Referer" => "example.com", "X-Title" => "Test Title"}
    response = Lux.LLM.OpenRouter.handle_headers(headers, "/completions")
    assert {:ok, _} = response
  end
end

@doc """
  Handles chat requests using the OpenRouter LLM.

  ## Parameters
  - `messages`: A list of messages in the format `[{"role": "user", "content": "message"}, ...]`.
  - `max_tokens`: Maximum number of tokens to generate (default: 50).

  ## Returns
  - A tuple with {:ok, response} or {:error, reason}
  """
  def chat(messages, max_tokens \\ 50) do
    params = %{
      "messages" => messages,
      "max_tokens" => max_tokens
    }

    request(:post, "/chat", params)
  end

def select_model(model, params \\ %{}) do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer System.get_env("OPEN_ROUTER_API_KEY")"}
    ]
    |> Enum.filter(fn {key, _value} -> key in ["HTTP-Referer", "X-Title"] end)

    request(:post, "/models/#{model}", params, headers)
  end