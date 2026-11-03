defmodule Lux.LLM.FallbackChainTest do
  use UnitCase, async: true

  alias Lux.LLM.FallbackChain

  describe "execute/2" do
    test "succeeds on first provider if healthy" do
      exec_fn = fn provider ->
        if provider == :openai, do: {:ok, "openai response"}, else: {:error, :unreachable}
      end

      assert {:ok, result, :openai, attempts} = FallbackChain.execute([:openai, :anthropic], exec_fn)
      assert result == "openai response"
      assert length(attempts) == 1
    end

    test "fails over to second provider if first fails" do
      exec_fn = fn provider ->
        case provider do
          :openai -> {:error, :rate_limit_429}
          :anthropic -> {:ok, "anthropic response"}
        end
      end

      assert {:ok, result, :anthropic, attempts} = FallbackChain.execute([:openai, :anthropic], exec_fn)
      assert result == "anthropic response"
      assert length(attempts) == 2
      assert hd(attempts).status == :failed
    end

    test "returns error when all providers in chain fail" do
      exec_fn = fn _p -> {:error, :timeout} end

      assert {:error, :all_providers_failed, attempts} = FallbackChain.execute([:openai, :anthropic], exec_fn)
      assert length(attempts) == 2
    end
  end
end
