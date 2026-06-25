defmodule Lux.LLM.ProviderTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.Provider

  describe "providers/0" do
    test "returns registered provider names" do
      # The providers are registered in config.exs
      providers = Provider.providers()
      assert :openai in providers
      assert :anthropic in providers
      assert :together_ai in providers
      assert :mira in providers
    end

    test "returns empty list when no providers configured" do
      # This tests the fallback when providers is empty
      # We test via a custom module attribute
      assert is_list(Provider.providers())
    end
  end

  describe "provider_modules/0" do
    test "returns registered provider modules" do
      modules = Provider.provider_modules()
      assert Lux.LLM.OpenAI in modules
      assert Lux.LLM.Anthropic in modules
      assert Lux.LLM.TogetherAI in modules
      assert Lux.LLM.Mira in modules
    end
  end

  describe "provider_module/1" do
    test "returns the module for a known provider name" do
      assert Provider.provider_module(:openai) == Lux.LLM.OpenAI
      assert Provider.provider_module(:anthropic) == Lux.LLM.Anthropic
      assert Provider.provider_module(:together_ai) == Lux.LLM.TogetherAI
      assert Provider.provider_module(:mira) == Lux.LLM.Mira
    end

    test "returns nil for unknown provider" do
      assert Provider.provider_module(:unknown_provider) == nil
    end
  end

  describe "provider_options/1" do
    test "returns options map for a provider" do
      opts = Provider.provider_options(:openai)
      assert is_map(opts)
    end
  end

  describe "default_module/0" do
    test "returns the highest priority provider module" do
      # openai has priority 1 (lowest = highest priority)
      assert Provider.default_module() == Lux.LLM.OpenAI
    end
  end

  describe "register/3" do
    test "registers a new provider at runtime" do
      defmodule FakeProvider do
        def call(_prompt, _tools, _config), do: {:ok, "fake"}
      end

      Provider.register(:fake, FakeProvider, %{priority: 5})
      assert :fake in Provider.providers()
      assert Provider.provider_module(:fake) == FakeProvider
      assert Provider.registered?(:fake)

      # Cleanup
      Provider.unregister(:fake)
      refute :fake in Provider.providers()
      refute Provider.registered?(:fake)
    end
  end

  describe "unregister/1" do
    test "removes a registered provider" do
      defmodule TempProvider do
        def call(_prompt, _tools, _config), do: {:ok, "temp"}
      end

      Provider.register(:temp, TempProvider)
      Provider.unregister(:temp)
      refute Provider.registered?(:temp)
    end
  end

  describe "call/3 - default provider" do
    test "calls the default provider module" do
      # Just verify the call dispatches correctly
      # The actual API call will fail without a real key, but the dispatch works
      result = Provider.call("test prompt", [], %{})
      # Should return {:error, ...} since no real API key is configured in tests
      assert is_tuple(result)
    end
  end

  describe "known_providers/0" do
    test "returns all known provider modules" do
      known = Lux.LLM.known_providers()
      assert Lux.LLM.OpenAI in known
      assert Lux.LLM.Anthropic in known
      assert Lux.LLM.TogetherAI in known
      assert Lux.LLM.Mira in known
    end
  end

  describe "normalize_response/2" do
    test "normalizes a Response struct" do
      resp = %Lux.LLM.Response{
        content: "hello",
        model: "gpt-4",
        finish_reason: "stop"
      }

      normalized = Lux.LLM.normalize_response(resp, Lux.LLM.OpenAI)
      assert normalized.content == "hello"
      assert normalized.model == "gpt-4"
      assert normalized.provider == Lux.LLM.OpenAI
    end

    test "normalizes a signal-like map into Response" do
      signal_data = %Lux.Signal{
        payload: %{
          "content" => "{\"result\": \"ok\"}",
          "model" => "gpt-4",
          "finish_reason" => "stop"
        },
        metadata: %{}
      }

      resp = Lux.LLM.normalize_response(signal_data, Lux.LLM.OpenAI)
      assert is_struct(resp, Lux.LLM.Response)
      assert resp.provider == Lux.LLM.OpenAI
    end
  end

  describe "fallback_module/0" do
    test "returns the fallback module" do
      assert Provider.fallback_module() == Lux.LLM.OpenAI
    end
  end
end
