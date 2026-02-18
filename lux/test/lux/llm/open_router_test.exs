# Lines 1-34 of lux/test/lux/llm/open_router_test.exs
defmodule Lux.LLM.OpenRouterTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.OpenRouter

  import HTTP

  describe "generate_text/2" do
    test "generates text with default max_tokens" do
      response = OpenRouter.generate_text("Hello, world!")

      assert {:ok, %{"choices" => [%{"text" => _}]}} = response
    end

    test "generates text with custom max_tokens" do
      response = OpenRouter.generate_text("Hello, world!", 100)

      assert {:ok, %{"choices" => [%{"text" => _}]}} = response
    end

    test "handles errors" do
      # Mock HTTP request to return an error
      allow(HTTP, :request, fn _, _, _, _ -> {:error, "Request failed"} end)

      response = OpenRouter.generate_text("Hello, world!")

      assert {:error, "Request failed"} = response
    end
  end
end

test "generates text with successful chat completion" do
  response = OpenRouter.generate_text("Hello, world!", :chat)

  assert {:ok, %{"choices" => [%{"text" => _}]}} = response
end

test "initializes OpenRouter with default settings" do
  response = OpenRouter.init()

  assert {:ok, %{"model" => "default", "max_tokens" => 50}} = response
end

test "initializes OpenRouter with custom settings" do
  response = OpenRouter.init(model: "gpt-4", max_tokens: 100)

  assert {:ok, %{"model" => "gpt-4", "max_tokens" => 100}} = response
end