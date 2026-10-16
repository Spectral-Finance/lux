defmodule Lux.LLM.RouterTest do
  use UnitAPICase, async: false

  alias Lux.LLM.CircuitBreaker
  alias Lux.LLM.Cost
  alias Lux.LLM.Registry
  alias Lux.LLM.Router
  alias Lux.LLM.Stats

  defmodule FailingProvider do
    @behaviour Lux.LLM
    @behaviour Lux.LLM.Provider

    @impl Lux.LLM.Provider
    def meta do
      %{
        name: :failing,
        models: [
          %{id: "f-cheap", input_cost_per_mtok: 0.25, output_cost_per_mtok: 0.5,
            max_context: 200_000, capabilities: [:tools]}
        ]
      }
    end

    @impl Lux.LLM
    def call(_prompt, _tools, _config), do: {:error, {500, "boom"}}
  end

  defmodule WorkingProvider do
    @behaviour Lux.LLM
    @behaviour Lux.LLM.Provider

    @impl Lux.LLM.Provider
    def meta do
      %{
        name: :working,
        models: [
          %{id: "w-pro", input_cost_per_mtok: 15.0, output_cost_per_mtok: 75.0,
            max_context: 200_000, capabilities: [:tools]}
        ]
      }
    end

    @impl Lux.LLM
    def call(_prompt, _tools, config) do
      Process.put(:router_test_last_config, config)
      {:ok, %Lux.LLM.Response{content: "ok"}}
    end
  end

  setup do
    start_supervised!(Registry)
    start_supervised!(Cost)
    start_supervised!(Stats)
    # threshold 1: a single exhausted provider opens its breaker,
    # default 30s cooldown keeps it open for the remainder of the test
    start_supervised!({CircuitBreaker, failure_threshold: 1})
    on_exit(fn -> Application.delete_env(:lux, Cost) end)
    :ok
  end

  describe "call/3" do
    test "returns the working provider's response when the first provider fails" do
      # the cheap failing provider ranks first thanks to cost + weight
      :ok = Registry.register(FailingProvider, weight: 2.0)
      :ok = Registry.register(WorkingProvider, weight: 0.1)

      assert {:ok, %Lux.LLM.Response{content: "ok"}} =
               Router.call("hello", [], backoff_ms: 0)

      # the failing provider was tried and recorded, then the fallback won
      snapshot = Stats.snapshot()
      assert snapshot.providers[:failing].calls >= 1
      assert snapshot.providers[:working].calls >= 1
    end

    test "retries transient errors up to max_attempts" do
      :ok = Registry.register(FailingProvider, weight: 2.0)
      :ok = Registry.register(WorkingProvider, weight: 0.1)

      assert {:ok, _} = Router.call("hello", [], max_attempts: 3, backoff_ms: 0)
      assert Stats.snapshot().providers[:failing].calls >= 3
    end

    test "skips a provider whose circuit breaker is open" do
      :ok = Registry.register(FailingProvider, weight: 2.0)
      :ok = Registry.register(WorkingProvider, weight: 0.1)

      # first call: one failure opens the breaker (threshold 1)
      assert {:ok, _} = Router.call("hello", [], max_attempts: 1, backoff_ms: 0)
      assert CircuitBreaker.status(FailingProvider) == :open

      # second call: the failing provider is skipped entirely
      snapshot_before = Stats.snapshot().providers[:failing].calls
      assert {:ok, _} = Router.call("hello", [], max_attempts: 1, backoff_ms: 0)
      assert Stats.snapshot().providers[:failing].calls == snapshot_before
    end

    test "respects an explicit provider allow-list" do
      :ok = Registry.register(FailingProvider, weight: 2.0)
      :ok = Registry.register(WorkingProvider, weight: 0.1)

      assert {:error, {500, "boom"}} =
               Router.call("hello", [], providers: [FailingProvider], max_attempts: 1, backoff_ms: 0)
    end

    test "returns :no_provider_available when the registry is empty" do
      assert {:error, :no_provider_available} = Router.call("hello", [])
    end

    test "fails fast when the global budget is exhausted" do
      Application.put_env(:lux, Cost, budget_usd: 0.0)
      :ok = Registry.register(WorkingProvider)

      assert {:error, :budget_exceeded} = Router.call("hello", [])
    end

    test "force: true bypasses the global budget" do
      Application.put_env(:lux, Cost, budget_usd: 0.0)
      :ok = Registry.register(WorkingProvider)

      assert {:ok, _} = Router.call("hello", [], force: true)
    end

    test "per-call budget_usd rejects calls priced above the ceiling" do
      :ok = Registry.register(WorkingProvider)

      # 1M input tokens at 15 USD/mtok is far above a 0.05 USD ceiling
      assert {:error, :budget_exceeded} =
               Router.call("hello", [], budget_usd: 0.05, requirements: [prompt_tokens: 1_000_000])
    end

    test "records usage of successful calls through Lux.LLM.Cost" do
      :ok = Registry.register(WorkingProvider)

      assert {:ok, _} = Router.call("hello", [])
      report = Cost.report()
      assert report.calls == 1
      assert report.total_usd > 0.0
      assert report.by_provider[:working] > 0.0
    end

    test "honours the selector's model choice" do
      :ok = Registry.register(WorkingProvider)

      assert {:ok, _} = Router.call("hello", [], requirements: [prompt_tokens: 1_000])

      # the provider received the model the selector injected into the entry
      assert %{model: "w-pro"} = Process.get(:router_test_last_config)
    end
  end
end
