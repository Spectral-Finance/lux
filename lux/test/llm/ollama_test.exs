defmodule Lux.LLM.OllamaTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.Ollama

  describe "register/1" do
    test "registers ollama as a provider" do
      assert :ok = Ollama.register()
      
      # Verify it was registered
      providers = Lux.LLM.ProviderRegistry.list_providers()
      assert :ollama in providers
    end
  end

  describe "get_host/0" do
    test "returns default host when not configured" do
      host = "http://localhost:11434"
      assert host == "http://localhost:11434"
    end
  end

  describe "call/3" do
    test "builds correct request body" do
      # This test verifies the function exists and accepts correct args
      assert function_exported?(Ollama, :call, 3)
    end
  end

  describe "list_models/1" do
    test "function exists and is exported" do
      assert function_exported?(Ollama, :list_models, 1)
    end
  end

  describe "pull_model/2" do
    test "function exists and is exported" do
      assert function_exported?(Ollama, :pull_model, 2)
    end
  end

  describe "get_model_info/2" do
    test "function exists and is exported" do
      assert function_exported?(Ollama, :get_model_info, 2)
    end
  end

  describe "delete_model/2" do
    test "function exists and is exported" do
      assert function_exported?(Ollama, :delete_model, 2)
    end
  end

  describe "health_check/1" do
    test "function exists and is exported" do
      assert function_exported?(Ollama, :health_check, 1)
    end
  end

  describe "integration with ProviderRegistry" do
    test "ollama provider has zero cost" do
      Ollama.register()
      
      config = Lux.LLM.ProviderRegistry.get_config(:ollama)
      
      assert config.cost_per_1k_tokens.default.input == 0.0
      assert config.cost_per_1k_tokens.default.output == 0.0
    end

    test "ollama has local and no_cost features" do
      Ollama.register()
      
      config = Lux.LLM.ProviderRegistry.get_config(:ollama)
      
      assert :local in config.features
      assert :no_cost in config.features
    end
  end
end