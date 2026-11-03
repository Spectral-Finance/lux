defmodule Lux.LLM.RouterAndFallbackTest do
  use UnitCase, async: true

  alias Lux.LLM.Router
  alias Lux.LLM.FallbackManager
  alias Lux.LLM.Registry

  describe "Lux.LLM.Router" do
    test "selects cost optimized provider" do
      {:ok, selection} = Router.select_provider(%{strategy: :cost_optimized})
      assert selection.cost_tier in [:free, :economy]
    end

    test "selects reasoning quality provider" do
      {:ok, selection} = Router.select_provider(%{strategy: :reasoning_quality})
      assert selection.cost_tier in [:premium, :standard]
    end

    test "selects offline privacy provider" do
      {:ok, selection} = Router.select_provider(%{strategy: :offline_privacy})
      assert :local in selection.capabilities
      assert selection.provider_id == :ollama
    end

    test "respects tool requirements" do
      {:ok, selection} = Router.select_provider(%{strategy: :balanced, require_tools: true})
      assert :tool_calling in selection.capabilities
    end

    test "respects preferred provider when available" do
      {:ok, selection} = Router.select_provider(%{preferred_provider: :anthropic})
      assert selection.provider_id == :anthropic
    end
  end

  describe "Lux.LLM.FallbackManager" do
    test "executes fallback when primary provider is unavailable" do
      # Set up mock module that fails first, then succeeds
      defmodule FailingProviderMock do
        def call(_prompt, _tools, _opts), do: {:error, :rate_limit_exceeded}
      end

      defmodule WorkingProviderMock do
        alias Lux.LLM.Response
        def call(_prompt, _tools, _opts), do: {:ok, %Response{content: "Fallback successful"}}
      end

      Registry.register_provider(%{
        id: :mock_fail,
        name: "Failing Mock",
        module: FailingProviderMock,
        enabled: true,
        priority: 1
      })

      Registry.register_provider(%{
        id: :mock_ok,
        name: "Working Mock",
        module: WorkingProviderMock,
        enabled: true,
        priority: 2
      })

      {:ok, resp, meta} =
        FallbackManager.execute_with_fallback("test prompt", [], %{
          fallback_chain: [:mock_fail, :mock_ok]
        })

      assert resp.content == "Fallback successful"
      assert meta.successful_provider == :mock_ok
      assert meta.attempts_count == 2
      assert length(meta.fallback_history) == 1
    end
  end
end
