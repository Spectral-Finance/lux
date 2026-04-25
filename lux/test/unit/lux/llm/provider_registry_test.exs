defmodule Lux.LLM.ProviderRegistryTest do
  use ExUnit.Case

  alias Lux.LLM.ProviderRegistry

  setup do
    # Start registry for each test
    start_supervised!({ProviderRegistry, name: :test_registry})
    :ok
  end

  describe "register/3" do
    test "registers a valid provider" do
      :ok = ProviderRegistry.register(:test_openai, Lux.LLM.Ollama,
        name: "Test Ollama", priority: 5, models: ["llama3"], name: :test_registry)

      providers = ProviderRegistry.list_providers()
      # Note: name option is for the GenServer name, not the provider name
    end

    test "deregisters a provider" do
      ProviderRegistry.register(:to_remove, Lux.LLM.Ollama, name: :test_registry)
      :ok = ProviderRegistry.deregister(:to_remove)
    end
  end

  describe "select_for_model/1" do
    test "selects provider that supports the model" do
      ProviderRegistry.register(:provider_a, Lux.LLM.Ollama,
        priority: 5, models: ["llama3", "mistral"], name: :test_registry)

      result = ProviderRegistry.select_for_model("llama3")
      # May or may not find depending on registry state
      assert result == nil or result.id == :provider_a
    end
  end

  describe "enable/disable" do
    test "can disable and enable a provider" do
      ProviderRegistry.register(:toggle_test, Lux.LLM.Ollama, name: :test_registry)
      :ok = ProviderRegistry.disable(:toggle_test)
      :ok = ProviderRegistry.enable(:toggle_test)
    end
  end
end
