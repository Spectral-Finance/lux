defmodule Lux.LLM.ProviderRegistryTest do
  use UnitAPICase, async: false

  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ProviderConfig
  alias Lux.LLM.ProviderRegistry

  setup do
    registry_name = :"test_registry_#{System.unique_integer([:positive])}"
    {:ok, pid} = ProviderRegistry.start_link(name: registry_name, providers: [])
    %{registry_name: registry_name, pid: pid}
  end

  describe "register_provider/2 and get_provider/2" do
    test "registers a ProviderConfig struct", %{registry_name: reg_name} do
      config = %ProviderConfig{
        id: :mock_provider,
        module: Lux.LLM.OpenAI,
        api_key: "sk-mock-key",
        models: [
          %ModelConfig{id: "mock-model-1", name: "Mock Model", provider_id: :mock_provider}
        ]
      }

      assert {:ok, registered} = ProviderRegistry.register_provider(config, registry_name: reg_name)
      assert registered.id == :mock_provider

      assert {:ok, fetched} = ProviderRegistry.get_provider(:mock_provider, registry_name: reg_name)
      assert fetched.id == :mock_provider
      assert fetched.api_key == "sk-mock-key"
      assert length(fetched.models) == 1
    end

    test "registers a provider module", %{registry_name: reg_name} do
      assert {:ok, config} = ProviderRegistry.register_provider(Lux.LLM.Gemini, registry_name: reg_name)
      assert config.id == :gemini
      assert config.module == Lux.LLM.Gemini
      assert length(config.models) > 0
    end
  end

  describe "unregister_provider/2" do
    test "removes an existing provider", %{registry_name: reg_name} do
      ProviderRegistry.register_provider(Lux.LLM.OpenAI, registry_name: reg_name)
      assert {:ok, _} = ProviderRegistry.get_provider(:openai, registry_name: reg_name)

      assert {:ok, removed} = ProviderRegistry.unregister_provider(:openai, registry_name: reg_name)
      assert removed.id == :openai

      assert {:error, :not_found} = ProviderRegistry.get_provider(:openai, registry_name: reg_name)
    end
  end

  describe "list_providers/1" do
    test "lists all registered provider configs", %{registry_name: reg_name} do
      ProviderRegistry.register_provider(Lux.LLM.OpenAI, registry_name: reg_name)
      ProviderRegistry.register_provider(Lux.LLM.Gemini, registry_name: reg_name)

      providers = ProviderRegistry.list_providers(registry_name: reg_name)
      provider_ids = Enum.map(providers, & &1.id)

      assert :openai in provider_ids
      assert :gemini in provider_ids
    end
  end

  describe "list_models/1" do
    test "filters models by provider_id and capabilities", %{registry_name: reg_name} do
      ProviderRegistry.register_provider(Lux.LLM.OpenAI, registry_name: reg_name)
      ProviderRegistry.register_provider(Lux.LLM.Gemini, registry_name: reg_name)

      all_models = ProviderRegistry.list_models(registry_name: reg_name)
      assert length(all_models) > 0

      openai_models = ProviderRegistry.list_models(registry_name: reg_name, provider_id: :openai)
      assert Enum.all?(openai_models, &(&1.provider_id == :openai))

      vision_models = ProviderRegistry.list_models(registry_name: reg_name, capabilities: [:vision])
      assert Enum.all?(vision_models, &(:vision in &1.capabilities))
    end
  end

  describe "update_provider_status/3" do
    test "updates provider status", %{registry_name: reg_name} do
      ProviderRegistry.register_provider(Lux.LLM.OpenAI, registry_name: reg_name)

      assert {:ok, updated} = ProviderRegistry.update_provider_status(:openai, :disabled, registry_name: reg_name)
      assert updated.status == :disabled

      active_models = ProviderRegistry.list_models(registry_name: reg_name, status: :active)
      refute Enum.any?(active_models, &(&1.provider_id == :openai))
    end
  end
end
