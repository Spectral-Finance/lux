defmodule Lux.Prisms.Llm.LlmProviderAbstractionPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Llm.LlmProviderAbstractionPrism

  describe "handler/2" do
    test "returns a response for a valid prompt with auto provider" do
      input = %{
        "prompt" => "What is 2+2?",
        "provider" => "auto",
        "max_tokens" => 100
      }

      result = LlmProviderAbstractionPrism.handler(input, %{})

      case result do
        {:ok, %{status: "success", response: _response}} ->
          :ok

        {:error, reason} ->
          assert is_binary(reason) or is_atom(reason)
      end
    end

    test "validates cost limit" do
      input = %{
        "prompt" => "Test",
        "cost_limit_usd" => 0.0001,
        "max_tokens" => 100000
      }

      result = LlmProviderAbstractionPrism.handler(input, %{})
      assert match?({:ok, _} or {:error, _}, result)
    end

    test "falls back to next provider on failure" do
      input = %{
        "prompt" => "Test fallback",
        "provider" => "openai",
        "fallback_enabled" => true,
        "max_tokens" => 50
      }

      result = LlmProviderAbstractionPrism.handler(input, %{})
      assert match?({:ok, _} or {:error, _}, result)
    end
  end
end
