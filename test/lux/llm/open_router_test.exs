defmodule Lux.LLM.OpenRouterTest do
  use ExUnit.Case
  alias Lux.LLM.OpenRouter

  @api_key "your_open_router_api_key"
  @base_url "https://api.openrouter.com/v1"

  setup do
    {:ok, api_key: @api_key}
  end

  test "generates text using the OpenRouter LLM", %{api_key: api_key} do
    System.put_env("OPEN_ROUTER_API_KEY", api_key)

    response = OpenRouter.generate_text("Hello, world!", 50)

    assert {:ok, _response} = response
  end

  test "handles HTTP-Referer and X-Title headers in requests", %{api_key: api_key} do
    System.put_env("OPEN_ROUTER_API_KEY", api_key)
    headers = %{"HTTP-Referer" => "example.com", "X-Title" => "Test Title"}
    endpoint = "/completions"
    params = %{"prompt" => "Hello, world!", "max_tokens" => 50}

    response = OpenRouter.handle_headers(headers, endpoint, params)

    assert {:ok, _response} = response
  end
end