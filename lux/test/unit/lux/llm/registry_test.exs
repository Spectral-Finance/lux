defmodule Lux.LLM.RegistryTest do
  use UnitCase, async: false

  alias Lux.LLM.Registry

  # The registry is started by the application, so it should already be running.
  # We test against the live ETS tables.

  describe "register/3 and get/1" do
    test "registers and retrieves a provider" do
      Registry.register(:test_provider, Lux.LLM.OpenAI, priority: 75)
      assert {:ok, Lux.LLM.OpenAI} = Registry.get(:test_provider)

      # Cleanup
      Registry.unregister(:test_provider)
    end

    test "returns :error for unregistered provider" do
      assert :error = Registry.get(:nonexistent_provider_xyz)
    end

    test "resolves module atoms directly if they implement call/3" do
      assert {:ok, Lux.LLM.OpenAI} = Registry.get(Lux.LLM.OpenAI)
    end
  end

  describe "get!/1" do
    test "returns module for valid provider" do
      assert Lux.LLM.OpenAI == Registry.get!(:openai)
    end

    test "raises for invalid provider" do
      assert_raise RuntimeError, ~r/not found/, fn ->
        Registry.get!(:nonexistent_provider_xyz)
      end
    end
  end

  describe "list/0 and list_names/0" do
    test "lists default providers" do
      providers = Registry.list()
      names = Enum.map(providers, fn {name, _mod, _prio} -> name end)

      assert :openai in names
      assert :anthropic in names
      assert :together_ai in names
      assert :mira in names
    end

    test "list_names returns atom list" do
      names = Registry.list_names()
      assert is_list(names)
      assert :openai in names
    end
  end

  describe "unregister/1" do
    test "removes a provider" do
      Registry.register(:temp_provider, Lux.LLM.OpenAI)
      assert {:ok, _} = Registry.get(:temp_provider)

      Registry.unregister(:temp_provider)
      assert :error = Registry.get(:temp_provider)
    end
  end

  describe "provider_info/1" do
    test "returns info for provider with provider_info/0" do
      assert {:ok, info} = Registry.provider_info(:openai)
      assert info.name == :openai
      assert info.display_name == "OpenAI"
      assert length(info.models) > 0
    end

    test "returns basic info for provider without provider_info/0" do
      defmodule BasicProvider do
        def call(_prompt, _tools, _config), do: {:ok, %{}}
      end

      Registry.register(:basic, BasicProvider)
      assert {:ok, info} = Registry.provider_info(:basic)
      assert info.name == :basic

      Registry.unregister(:basic)
    end

    test "returns :error for unknown provider" do
      assert :error = Registry.provider_info(:nonexistent_xyz)
    end
  end

  describe "health tracking" do
    test "report_health/3 and health/1" do
      Registry.report_health(:openai, :ok, 500)
      health = Registry.health(:openai)

      assert health.total_requests >= 1
      assert health.avg_latency_ms > 0
      assert health.consecutive_errors == 0
    end

    test "tracks consecutive errors" do
      Registry.report_health(:test_health_provider, :error, 100)
      Registry.report_health(:test_health_provider, :error, 200)
      Registry.report_health(:test_health_provider, :error, 300)

      health = Registry.health(:test_health_provider)
      assert health.consecutive_errors == 3
      assert health.error_count == 3
    end

    test "resets consecutive errors on success" do
      Registry.report_health(:test_reset_provider, :error, 100)
      Registry.report_health(:test_reset_provider, :error, 100)
      Registry.report_health(:test_reset_provider, :ok, 100)

      health = Registry.health(:test_reset_provider)
      assert health.consecutive_errors == 0
      assert health.error_count == 2
    end

    test "health returns nil for unknown provider" do
      assert nil == Registry.health(:totally_unknown_provider)
    end
  end

  describe "health_score/1" do
    test "returns 0.5 for unknown provider" do
      assert 0.5 == Registry.health_score(:totally_unknown_provider)
    end

    test "returns high score for healthy provider" do
      for _ <- 1..10 do
        Registry.report_health(:healthy_score_test, :ok, 100)
      end

      score = Registry.health_score(:healthy_score_test)
      assert score > 0.8
    end

    test "returns low score for unhealthy provider" do
      for _ <- 1..10 do
        Registry.report_health(:unhealthy_score_test, :error, 10_000)
      end

      score = Registry.health_score(:unhealthy_score_test)
      assert score < 0.4
    end
  end

  describe "healthy_providers/0" do
    test "returns providers sorted by health score" do
      providers = Registry.healthy_providers()
      assert is_list(providers)

      scores = Enum.map(providers, fn {_name, _mod, score} -> score end)
      assert scores == Enum.sort(scores, :desc)
    end
  end
end
