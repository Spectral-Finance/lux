defmodule Lux.LLM.FallbackChainTest do
  use ExUnit.Case, async: false

  alias Lux.LLM.CircuitBreaker
  alias Lux.LLM.FallbackChain
  alias Lux.LLM.Registry

  defmodule SuccessProvider do
    def call(_prompt, _tools, _config), do: {:ok, %{content: "ok"}}
  end

  defmodule FailProvider do
    def call(_prompt, _tools, _config), do: {:error, :boom}
  end

  setup do
    {:ok, reg} = Registry.start_link(name: :fc_registry, table: :fc_registry_ets)
    {:ok, cb_pid} = CircuitBreaker.start_link(name: :fc_cb, failure_threshold: 3)

    Registry.register(:success_p, %{module: SuccessProvider, config: %{}}, :fc_registry)
    Registry.register(:fail_p, %{module: FailProvider, config: %{}}, :fc_registry)

    on_exit(fn ->
      if Process.alive?(reg), do: Process.exit(reg, :kill)
      if Process.alive?(cb_pid), do: Process.exit(cb_pid, :kill)
    end)

    %{cb: :fc_cb}
  end

  describe "call/3" do
    test "succeeds immediately on first available provider", %{cb: cb} do
      assert {:ok, %{content: "ok"}} =
               FallbackChain.call([:success_p], %{prompt: "hi", tools: [], config: %{}}, cb)
    end

    test "falls back to second provider when first fails", %{cb: cb} do
      assert {:ok, _} =
               FallbackChain.call(
                 [:fail_p, :success_p],
                 %{prompt: "hi", tools: [], config: %{}},
                 cb
               )
    end

    test "returns all_failed with reasons when all providers fail", %{cb: cb} do
      assert {:error, :all_failed, failures} =
               FallbackChain.call(
                 [:fail_p],
                 %{prompt: "hi", tools: [], config: %{}},
                 cb
               )

      assert [{:fail_p, :boom}] = failures
    end

    test "skips open-circuit providers and falls back", %{cb: cb} do
      Enum.each(1..3, fn _ -> CircuitBreaker.record_failure(:fail_p, cb) end)

      assert {:ok, _} =
               FallbackChain.call(
                 [:fail_p, :success_p],
                 %{prompt: "hi", tools: [], config: %{}},
                 cb
               )
    end

    test "reports circuit_open in failure log when skipped", %{cb: cb} do
      Enum.each(1..3, fn _ -> CircuitBreaker.record_failure(:fail_p, cb) end)

      assert {:error, :all_failed, failures} =
               FallbackChain.call(
                 [:fail_p],
                 %{prompt: "hi", tools: [], config: %{}},
                 cb
               )

      assert [{:fail_p, :circuit_open}] = failures
    end

    test "returns provider_not_registered for unknown provider", %{cb: cb} do
      assert {:error, :all_failed, [{:ghost, {:provider_not_registered, :ghost}}]} =
               FallbackChain.call(
                 [:ghost],
                 %{prompt: "hi", tools: [], config: %{}},
                 cb
               )
    end
  end
end
