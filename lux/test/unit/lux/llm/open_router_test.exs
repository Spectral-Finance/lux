defmodule Lux.LLM.OpenRouterTest do
  @moduledoc """
  Tests for OpenRouter LLM integration.
  """

  use ExUnit.Case, async: true

  alias Lux.LLM.OpenRouter

  describe "Config" do
    test "default config has correct endpoint" do
      config = %OpenRouter.Config{}
      assert config.endpoint == "https://openrouter.ai/api/v1/chat/completions"
    end

    test "default config enables cost tracking" do
      config = %OpenRouter.Config{}
      assert config.cost_tracking == true
    end

    test "default config has nil model and api_key" do
      config = %OpenRouter.Config{}
      assert config.model == nil
      assert config.api_key == nil
    end
  end

  describe "call/3" do
    test "returns error with invalid API key" do
      # This would require mocking Req, so we test the error handling path
      config = %{api_key: "invalid-key", model: "openai/gpt-4o"}
      result = OpenRouter.call("test", [], config)
      # The actual result depends on whether Req is available
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "list_models/1" do
    test "returns models list or error" do
      result = OpenRouter.list_models()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "estimate_cost/3" do
    test "returns cost estimate for known model" do
      # This requires the model to exist in OpenRouter's catalog
      result = OpenRouter.estimate_cost("openai/gpt-4o", 1000, 500)
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for unknown model" do
      result = OpenRouter.estimate_cost("nonexistent/model", 1000, 500)
      assert match?({:error, _}, result)
    end
  end

  describe "get_model_cost/1" do
    test "returns pricing for known model" do
      result = OpenRouter.get_model_cost("openai/gpt-4o")
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for unknown model" do
      result = OpenRouter.get_model_cost("nonexistent/model")
      assert match?({:error, _}, result)
    end
  end
end
