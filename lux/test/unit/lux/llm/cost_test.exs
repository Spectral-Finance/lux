defmodule Lux.LLM.CostTest do
  use UnitAPICase, async: false

  alias Lux.LLM.Cost
  alias Lux.LLM.Registry

  defmodule PricedProvider do
    @behaviour Lux.LLM
    @behaviour Lux.LLM.Provider

    @impl Lux.LLM.Provider
    def meta do
      %{
        name: :priced,
        models: [
          %{id: "priced-mini", input_cost_per_mtok: 1.0, output_cost_per_mtok: 2.0,
            max_context: 8_000, capabilities: [:tools]}
        ]
      }
    end

    @impl Lux.LLM
    def call(_prompt, _tools, _options), do: {:error, :not_implemented}
  end

  setup do
    start_supervised!(Registry)
    start_supervised!(Cost)
    :ok = Registry.register(PricedProvider)
    on_exit(fn -> Application.delete_env(:lux, Cost) end)
    :ok
  end

  describe "price/3" do
    test "prices a call from the model metadata" do
      assert_in_delta Cost.price("priced-mini", 1_000_000, 0), 1.0, 0.0001
      assert_in_delta Cost.price("priced-mini", 0, 1_000_000), 2.0, 0.0001
      assert_in_delta Cost.price("priced-mini", 500_000, 500_000), 1.5, 0.0001
    end

    test "unknown models price at zero" do
      assert Cost.price("unknown-model", 100, 100) == 0.0
    end
  end

  describe "record/4 and report/0" do
    test "records usage and aggregates per provider" do
      cost = Cost.record(:priced, "priced-mini", 500_000, 250_000)
      assert_in_delta cost, 1.0, 0.0001

      report = Cost.report()
      assert report.calls == 1
      assert_in_delta report.total_usd, 1.0, 0.0001
      assert_in_delta report.by_provider[:priced], 1.0, 0.0001

      _ = Cost.record(:priced, "priced-mini", 250_000, 0)
      assert Cost.report().calls == 2
      assert_in_delta Cost.report().total_usd, 1.25, 0.0001
    end

    test "reset/0 clears recorded usage" do
      _ = Cost.record(:priced, "priced-mini", 100, 100)
      :ok = Cost.reset()

      report = Cost.report()
      assert report.calls == 0
      assert report.total_usd == 0.0
    end
  end

  describe "exceeded?/0" do
    test "respects the configured budget" do
      refute Cost.exceeded?()

      Application.put_env(:lux, Cost, budget_usd: 0.5)
      _ = Cost.record(:priced, "priced-mini", 500_000, 250_000)
      assert Cost.exceeded?()

      Application.put_env(:lux, Cost, budget_usd: 100.0)
      refute Cost.exceeded?()
    end

    test "is false without a budget" do
      _ = Cost.record(:priced, "priced-mini", 500_000, 250_000)
      refute Cost.exceeded?()
    end
  end
end
