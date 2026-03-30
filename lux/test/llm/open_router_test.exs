defmodule Lux.LLM.OpenRouterTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.OpenRouter

  describe "register/1" do
    setup do
      # Ensure fresh registry state per test
      :ok = OpenRouter.register()
      on_exit(fn ->
        _ = :ets.delete(:lux_llm_provider_registry, :openrouter)
      end)
      :ok
    end

    test "registers openrouter as a provider" do
      assert :ok = OpenRouter.register()

      assert Lux.LLM.ProviderRegistry.registered?(:openrouter)
      assert :openrouter in Lux.LLM.ProviderRegistry.list_providers()
    end

    test "registers with correct module" do
      config = Lux.LLM.ProviderRegistry.get_config(:openrouter)
      assert config.module == Lux.LLM.OpenRouter
    end

    test "registers supported models" do
      models = Lux.LLM.ProviderRegistry.get_models(:openrouter)
      assert "anthropic/claude-3.5-sonnet" in models
      assert "openai/gpt-4o" in models
    end

    test "registers with correct features" do
      config = Lux.LLM.ProviderRegistry.get_config(:openrouter)
      assert :streaming in config.features
      assert :tools in config.features
      assert :json_mode in config.features
    end
  end

  describe "call/3" do
    test "accepts prompt, tools, and config arguments" do
      assert function_exported?(OpenRouter, :call, 3)
    end

    @tag :external
    test "returns error tuple on invalid API key", %{test: name} do
      result = OpenRouter.call("hello", [], %{api_key: "invalid_key"})
      assert {:error, _} = result
    end
  end

  describe "Config struct" do
    test "has correct defaults" do
      cfg = %OpenRouter.Config{}
      assert cfg.endpoint == "https://openrouter.ai/api/v1/chat/completions"
      assert cfg.model == "anthropic/claude-3.5-sonnet"
      assert cfg.temperature == 0.7
      assert cfg.tools == true
      assert cfg.tool_choice == :auto
      assert cfg.stream == false
      assert cfg.json_mode == false
      assert cfg.retries == 3
    end

    test "can be overridden via map" do
      cfg = struct(OpenRouter.Config, %{
        model: "openai/gpt-4o",
        temperature: 0.9,
        max_tokens: 1000
      })
      assert cfg.model == "openai/gpt-4o"
      assert cfg.temperature == 0.9
      assert cfg.max_tokens == 1000
      assert cfg.endpoint == "https://openrouter.ai/api/v1/chat/completions"
    end
  end

  describe "provider registry integration" do
    setup do
      :ok = OpenRouter.register()
      :ok
    end

    test "can be enabled and disabled" do
      assert :ok = Lux.LLM.ProviderRegistry.enable(:openrouter)
      assert :openrouter in Lux.LLM.ProviderRegistry.list_enabled()

      assert :ok = Lux.LLM.ProviderRegistry.disable(:openrouter)
      refute :openrouter in Lux.LLM.ProviderRegistry.list_enabled()
    end

    test "has correct cost info" do
      config = Lux.LLM.ProviderRegistry.get_config(:openrouter)
      assert is_map(config.cost_per_1k_tokens)
      assert config.max_tokens == 128_000

      costs = config.cost_per_1k_tokens
      assert costs["anthropic/claude-3.5-sonnet"].input > 0
      assert costs["openai/gpt-4o-mini"].input < costs["openai/gpt-4o"].input
    end
  end

  describe "tool_to_function conversion" do
    alias Lux.LLM.OpenRouter

    test "converts Beam struct to OpenAI tool format" do
      beam = %Lux.Beam{
        module_name: "GitHub.CreateIssue",
        description: "Create a GitHub issue",
        input_schema: %{"type" => "object", "properties" => %{"title" => %{"type" => "string"}}}
      }
      result = OpenRouter.tool_to_function(beam)
      assert result["type"] == "function"
      assert result["function"]["name"] == "GitHub_CreateIssue"
      assert result["function"]["description"] == "Create a GitHub issue"
    end

    test "converts Lens struct to OpenAI tool format" do
      lens = %Lux.Lens{
        name: "web_search",
        description: "Search the web",
        schema: %{"type" => "object", "properties" => %{"query" => %{"type" => "string"}}}
      }
      result = OpenRouter.tool_to_function(lens)
      assert result["type"] == "function"
      assert result["function"]["name"] == "web_search"
    end

    test "handles nil description gracefully" do
      beam = %Lux.Beam{
        module_name: "TestTool",
        description: nil,
        input_schema: %{"type" => "object", "properties" => %{}}
      }
      result = OpenRouter.tool_to_function(beam)
      assert result["function"]["description"] == ""
    end
  end

  describe "json_mode" do
    test "config struct supports json_mode field" do
      cfg = struct(OpenRouter.Config, %{json_mode: true})
      assert cfg.json_mode == true
    end
  end
end
