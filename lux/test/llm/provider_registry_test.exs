defmodule Lux.LLM.ProviderRegistryTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.ProviderRegistry

  setup do
    # Registry is started by application supervisor
    :ok
  end

  describe "register/2" do
    test "registers a new provider" do
      assert :ok == ProviderRegistry.register(:test_provider, %{
        module: SomeModule,
        models: ["test-model"]
      })

      assert ProviderRegistry.registered?(:test_provider)

      # Cleanup
      ProviderRegistry.unregister(:test_provider)
    end

    test "returns error for invalid config" do
      assert {:error, {:missing_keys, [:module]}} == ProviderRegistry.register(:bad, %{})
    end
  end

  describe "unregister/1" do
    test "unregisters a provider" do
      ProviderRegistry.register(:temp, %{module: SomeModule})

      assert :ok == ProviderRegistry.unregister(:temp)
      refute ProviderRegistry.registered?(:temp)
    end
  end

  describe "list_providers/0" do
    test "returns list of all providers" do
      providers = ProviderRegistry.list_providers()

      assert is_list(providers)
      assert :openai in providers
      assert :anthropic in providers
      assert :together_ai in providers
    end
  end

  describe "get_config/1" do
    test "returns provider configuration" do
      config = ProviderRegistry.get_config(:openai)

      assert is_map(config)
      assert config.module == Lux.LLM.OpenAI
      assert "gpt-4" in config.models
    end

    test "returns nil for unknown provider" do
      assert nil == ProviderRegistry.get_config(:unknown)
    end
  end

  describe "enable/1 and disable/1" do
    test "toggles provider enabled state" do
      # Create a test provider
      ProviderRegistry.register(:toggle_test, %{module: SomeModule, enabled: true})

      assert :ok == ProviderRegistry.disable(:toggle_test)
      config = ProviderRegistry.get_config(:toggle_test)
      refute config.enabled

      assert :ok == ProviderRegistry.enable(:toggle_test)
      config = ProviderRegistry.get_config(:toggle_test)
      assert config.enabled

      # Cleanup
      ProviderRegistry.unregister(:toggle_test)
    end
  end

  describe "get_models/1" do
    test "returns models for provider" do
      models = ProviderRegistry.get_models(:openai)

      assert is_list(models)
      assert "gpt-4" in models
    end
  end
end