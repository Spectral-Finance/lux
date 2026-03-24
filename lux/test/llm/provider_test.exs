defmodule Lux.LLM.ProviderTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.Provider

  describe "list_providers/0" do
    test "returns list of registered providers" do
      providers = Provider.list_providers()

      assert is_list(providers)
      assert :openai in providers
      assert :anthropic in providers
    end
  end

  describe "get_config/1" do
    test "returns config for registered provider" do
      config = Provider.get_config(:openai)

      assert is_map(config)
      assert Map.has_key?(config, :module)
      assert Map.has_key?(config, :models)
    end

    test "returns nil for unregistered provider" do
      assert Provider.get_config(:nonexistent) == nil
    end
  end

  describe "select_best/1" do
    test "selects provider based on priority" do
      {:provider, _provider, _model} = {:ok, Provider.select_best(%{priority: :cost})}

      # Cost priority should select cheaper provider
      result = Provider.select_best(%{priority: :cost})
      assert match?({_, _}, result)
    end

    test "returns error when no providers match requirements" do
      result = Provider.select_best(%{exclude: Provider.list_providers()})

      assert result == {:error, :no_matching_providers}
    end
  end
end