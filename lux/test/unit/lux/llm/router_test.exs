defmodule Lux.LLM.RouterTest do
  use ExUnit.Case, async: false

  alias Lux.LLM.Router
  alias Lux.LLM.Router.Config

  defmodule MockProviderSuccess do
    @behaviour Lux.LLM
    def call(prompt, _tools, _opts) do
      {:ok, %{content: "response for: #{prompt}", provider: :mock_success}}
    end
  end

  defmodule MockProviderFail do
    @behaviour Lux.LLM
    def call(_prompt, _tools, _opts) do
      {:error, :rate_limit_exceeded}
    end
  end

  defmodule MockProviderSecondary do
    @behaviour Lux.LLM
    def call(prompt, _tools, _opts) do
      {:ok, %{content: "fallback response for: #{prompt}", provider: :mock_secondary}}
    end
  end

  setup do
    Router.register_provider(:mock_a, MockProviderFail)
    Router.register_provider(:mock_b, MockProviderSecondary)
    Router.register_provider(:mock_ok, MockProviderSuccess)
    :ok
  end

  describe "registry" do
    test "resolves registered providers" do
      assert Router.resolve_provider(:mock_ok) == MockProviderSuccess
      assert Router.resolve_provider(:mock_a) == MockProviderFail
      assert Router.resolve_provider(MockProviderSuccess) == MockProviderSuccess
    end
  end

  describe "build_provider_chain/1" do
    test "resolves :local strategy to [:ollama]" do
      assert Router.build_provider_chain(%Config{strategy: :local}) == [:ollama]
    end

    test "resolves :cheapest strategy with primary prioritized" do
      chain = Router.build_provider_chain(%Config{strategy: :cheapest, primary_provider: :ollama})
      assert hd(chain) == :ollama
    end

    test "resolves custom primary and fallbacks" do
      chain =
        Router.build_provider_chain(%Config{
          primary_provider: :mock_a,
          fallback_providers: [:mock_b, :mock_ok]
        })

      assert chain == [:mock_a, :mock_b, :mock_ok]
    end
  end

  describe "call/3 routing & fallbacks" do
    test "executes primary provider when successful" do
      config = %Config{
        primary_provider: :mock_ok,
        fallback_providers: [:mock_b]
      }

      assert {:ok, %{content: "response for: hello", provider: :mock_success}} =
               Router.call("hello", [], config)
    end

    test "seamlessly switches to fallback provider when primary fails" do
      config = %Config{
        primary_provider: :mock_a,
        fallback_providers: [:mock_b]
      }

      assert {:ok, %{content: "fallback response for: test", provider: :mock_secondary}} =
               Router.call("test", [], config)
    end

    test "returns error when all providers fail" do
      config = %Config{
        primary_provider: :mock_a,
        fallback_providers: [:mock_a]
      }

      assert {:error, {:all_providers_failed, [{:mock_a, :rate_limit_exceeded}]}} =
               Router.call("test", [], config)
    end
  end
end
