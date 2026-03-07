defmodule Lux.LLM.ProviderRegistryTest do
  use UnitCase, async: true

  alias Lux.LLM.ProviderRegistry

  # ─── Test Helpers ─────────────────────────────────────────────────────────

  defmodule MockProvider do
    @moduledoc false
    @behaviour Lux.LLM

    @impl true
    def call(_prompt, _tools, config) do
      case Map.get(config, :should_fail, false) do
        true ->
          {:error, "mock failure"}

        false ->
          {:ok, %Lux.LLM.Response{
            content: "mock response",
            tool_calls: [],
            finish_reason: "stop"
          }}
      end
    end
  end

  defmodule MockProviderSlow do
    @moduledoc false
    @behaviour Lux.LLM

    @impl true
    def call(_prompt, _tools, _config) do
      Process.sleep(10)

      {:ok, %Lux.LLM.Response{
        content: "slow response",
        tool_calls: [],
        finish_reason: "stop"
      }}
    end
  end

  defmodule MockProviderFailing do
    @moduledoc false
    @behaviour Lux.LLM

    @impl true
    def call(_prompt, _tools, _config) do
      {:error, "always fails"}
    end
  end

  # Start a fresh registry for each test
  setup do
    name = :"registry_#{System.unique_integer([:positive])}"
    {:ok, pid} = ProviderRegistry.start_link(name: name)
    %{registry: name, pid: pid}
  end

  # ─── Registration Tests ──────────────────────────────────────────────────

  describe "register_provider/3" do
    test "registers a valid provider", %{registry: reg} do
      assert :ok =
               ProviderRegistry.register_provider(
                 :mock,
                 %{
                   module: MockProvider,
                   priority: 1,
                   models: ["mock-1", "mock-2"]
                 },
                 reg
               )
    end

    test "registers provider with all options", %{registry: reg} do
      assert :ok =
               ProviderRegistry.register_provider(
                 :mock,
                 %{
                   module: MockProvider,
                   priority: 5,
                   models: ["mock-1"],
                   config: %{api_key: "test-key"},
                   enabled: true,
                   rate_limit: 60,
                   tags: [:fast, :cheap]
                 },
                 reg
               )

      [provider] = ProviderRegistry.list_providers(reg)
      assert provider.name == :mock
      assert provider.config.priority == 5
      assert provider.config.tags == [:fast, :cheap]
      assert provider.config.rate_limit == 60
    end

    test "auto-registers model routes", %{registry: reg} do
      :ok =
        ProviderRegistry.register_provider(
          :mock,
          %{module: MockProvider, models: ["mock-model"]},
          reg
        )

      # Should be able to call with this model and have it routed
      result = ProviderRegistry.call("test", [], %{model: "mock-model"}, reg)
      assert {:ok, _} = result
    end
  end

  describe "unregister_provider/2" do
    test "removes a provider", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock, %{module: MockProvider}, reg)
      assert length(ProviderRegistry.list_providers(reg)) == 1

      :ok = ProviderRegistry.unregister_provider(:mock, reg)
      assert length(ProviderRegistry.list_providers(reg)) == 0
    end
  end

  describe "update_provider/3" do
    test "updates existing provider config", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock, %{module: MockProvider, priority: 10}, reg)
      :ok = ProviderRegistry.update_provider(:mock, %{priority: 1}, reg)

      [provider] = ProviderRegistry.list_providers(reg)
      assert provider.config.priority == 1
    end

    test "returns error for non-existent provider", %{registry: reg} do
      assert {:error, :not_found} = ProviderRegistry.update_provider(:nope, %{priority: 1}, reg)
    end
  end

  describe "set_provider_enabled/3" do
    test "enables and disables providers", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock, %{module: MockProvider}, reg)
      :ok = ProviderRegistry.set_provider_enabled(:mock, false, reg)

      [provider] = ProviderRegistry.list_providers(reg)
      assert provider.config.enabled == false

      :ok = ProviderRegistry.set_provider_enabled(:mock, true, reg)
      [provider] = ProviderRegistry.list_providers(reg)
      assert provider.config.enabled == true
    end
  end

  # ─── Provider Selection Tests ────────────────────────────────────────────

  describe "call/4 - provider selection" do
    test "selects provider by explicit model routing", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock, %{module: MockProvider, models: ["test-model"]}, reg)
      assert {:ok, _} = ProviderRegistry.call("hello", [], %{model: "test-model"}, reg)
    end

    test "selects provider by explicit :provider option", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock, %{module: MockProvider}, reg)
      assert {:ok, _} = ProviderRegistry.call("hello", [], %{provider: :mock}, reg)
    end

    test "selects provider by priority", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:slow, %{module: MockProviderSlow, priority: 10}, reg)
      :ok = ProviderRegistry.register_provider(:fast, %{module: MockProvider, priority: 1}, reg)

      assert {:ok, %{content: "mock response"}} =
               ProviderRegistry.call("hello", [], %{}, reg)
    end

    test "selects provider by tags", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:cheap, %{module: MockProvider, tags: [:cheap, :fast]}, reg)
      :ok = ProviderRegistry.register_provider(:expensive, %{module: MockProviderSlow, tags: [:reasoning]}, reg)

      assert {:ok, %{content: "mock response"}} =
               ProviderRegistry.call("hello", [], %{tags: [:cheap]}, reg)
    end

    test "skips disabled providers", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:disabled, %{module: MockProviderFailing, priority: 1, enabled: false}, reg)
      :ok = ProviderRegistry.register_provider(:enabled, %{module: MockProvider, priority: 10}, reg)

      assert {:ok, _} = ProviderRegistry.call("hello", [], %{}, reg)
    end
  end

  # ─── Fallback Tests ──────────────────────────────────────────────────────

  describe "call/4 - fallback handling" do
    test "falls back to next provider on failure", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:failing, %{module: MockProviderFailing, priority: 1}, reg)
      :ok = ProviderRegistry.register_provider(:working, %{module: MockProvider, priority: 2}, reg)

      assert {:ok, _} = ProviderRegistry.call("hello", [], %{fallback: true}, reg)
    end

    test "uses explicit fallback chain", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:primary, %{module: MockProviderFailing, priority: 1}, reg)
      :ok = ProviderRegistry.register_provider(:backup, %{module: MockProvider, priority: 10}, reg)
      :ok = ProviderRegistry.set_fallback_chain(:primary, [:backup], reg)

      assert {:ok, _} = ProviderRegistry.call("hello", [], %{provider: :primary, fallback: true}, reg)
    end

    test "does not fallback when fallback is disabled", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:failing, %{module: MockProviderFailing, priority: 1}, reg)
      :ok = ProviderRegistry.register_provider(:working, %{module: MockProvider, priority: 2}, reg)

      assert {:error, "always fails"} =
               ProviderRegistry.call("hello", [], %{provider: :failing, fallback: false}, reg)
    end

    test "returns error when all providers fail", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:fail1, %{module: MockProviderFailing, priority: 1}, reg)
      :ok = ProviderRegistry.register_provider(:fail2, %{module: MockProviderFailing, priority: 2}, reg)

      assert {:error, "always fails"} = ProviderRegistry.call("hello", [], %{}, reg)
    end

    test "returns error when no providers registered", %{registry: reg} do
      assert {:error, :no_providers_available} = ProviderRegistry.call("hello", [], %{}, reg)
    end
  end

  # ─── Statistics Tests ────────────────────────────────────────────────────

  describe "statistics tracking" do
    test "tracks successful calls", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock, %{module: MockProvider}, reg)
      {:ok, _} = ProviderRegistry.call("hello", [], %{provider: :mock}, reg)
      {:ok, _} = ProviderRegistry.call("hello", [], %{provider: :mock}, reg)

      {:ok, stats} = ProviderRegistry.get_stats(:mock, reg)
      assert stats.total_calls == 2
      assert stats.successful_calls == 2
      assert stats.failed_calls == 0
      assert stats.last_call_at != nil
    end

    test "tracks failed calls", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:failing, %{module: MockProviderFailing}, reg)
      {:error, _} = ProviderRegistry.call("hello", [], %{provider: :failing, fallback: false}, reg)

      {:ok, stats} = ProviderRegistry.get_stats(:failing, reg)
      assert stats.total_calls == 1
      assert stats.failed_calls == 1
      assert stats.last_error != nil
    end

    test "tracks latency", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:slow, %{module: MockProviderSlow}, reg)
      {:ok, _} = ProviderRegistry.call("hello", [], %{provider: :slow}, reg)

      {:ok, stats} = ProviderRegistry.get_stats(:slow, reg)
      assert stats.avg_latency_ms >= 10.0
    end

    test "resets stats for specific provider", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock, %{module: MockProvider}, reg)
      {:ok, _} = ProviderRegistry.call("hello", [], %{provider: :mock}, reg)
      :ok = ProviderRegistry.reset_stats(:mock, reg)

      {:ok, stats} = ProviderRegistry.get_stats(:mock, reg)
      assert stats.total_calls == 0
    end

    test "resets all stats", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock, %{module: MockProvider}, reg)
      {:ok, _} = ProviderRegistry.call("hello", [], %{provider: :mock}, reg)
      :ok = ProviderRegistry.reset_stats(:all, reg)

      {:ok, stats} = ProviderRegistry.get_stats(:mock, reg)
      assert stats.total_calls == 0
    end

    test "returns error for unknown provider stats", %{registry: reg} do
      assert {:error, :not_found} = ProviderRegistry.get_stats(:nonexistent, reg)
    end
  end

  # ─── Model Routing Tests ─────────────────────────────────────────────────

  describe "route_model/3" do
    test "routes specific models to providers", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock, %{module: MockProvider}, reg)
      :ok = ProviderRegistry.route_model("custom-model", :mock, reg)

      assert {:ok, _} = ProviderRegistry.call("hello", [], %{model: "custom-model"}, reg)
    end
  end

  # ─── List Providers Tests ────────────────────────────────────────────────

  describe "list_providers/1" do
    test "returns all providers with stats", %{registry: reg} do
      :ok = ProviderRegistry.register_provider(:mock1, %{module: MockProvider, priority: 1}, reg)
      :ok = ProviderRegistry.register_provider(:mock2, %{module: MockProvider, priority: 2}, reg)

      providers = ProviderRegistry.list_providers(reg)
      assert length(providers) == 2

      names = Enum.map(providers, & &1.name)
      assert :mock1 in names
      assert :mock2 in names
    end
  end
end
