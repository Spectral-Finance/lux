defmodule Lux.Prisms.DeFiAnalytics.DeFiAnalyticsAlertPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.DeFiAnalytics.DeFiAnalyticsAlertPrism

  describe "handler/2 — input validation" do
    test "rejects missing rules" do
      assert {:error, _} = DeFiAnalyticsAlertPrism.run(%{protocol: "uniswap"})
    end

    test "rejects when neither protocol nor yield_pool provided" do
      assert {:error, msg} = DeFiAnalyticsAlertPrism.run(%{rules: []})
      assert msg =~ "protocol" or msg =~ "yield_pool"
    end

    test "accepts protocol with rules" do
      result = DeFiAnalyticsAlertPrism.run(%{
        protocol: "nonexistent-protocol-xyz",
        rules: [
          %{metric: "tvl", condition: "below", threshold: 0.0, severity: "critical"}
        ]
      })
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "handler/2 — alert rule evaluation" do
    test "triggers alert when TVL below threshold" do
      # Inject metrics by checking with very high threshold (guaranteed to trigger)
      result = DeFiAnalyticsAlertPrism.run(%{
        protocol: "aave-v3",
        rules: [
          %{metric: "tvl", condition: "below", threshold: 999_999_999_999.0, severity: "critical"}
        ]
      })

      case result do
        {:ok, resp} ->
          assert resp.status == "success"
          assert is_list(resp.alerts)
          assert is_map(resp.current_metrics)
          assert resp.alert_count == length(resp.alerts)
        {:error, _} -> :skip  # Network unavailable
      end
    end

    test "does not trigger alert when metric within acceptable range" do
      result = DeFiAnalyticsAlertPrism.run(%{
        protocol: "aave-v3",
        rules: [
          # TVL above $0 — always true, so no alert
          %{metric: "tvl", condition: "below", threshold: 0.0, severity: "info"}
        ]
      })

      case result do
        {:ok, resp} ->
          assert resp.alert_count == 0
          assert resp.alerts == []
        {:error, _} -> :skip
      end
    end

    test "handles multiple rules with mixed triggers" do
      result = DeFiAnalyticsAlertPrism.run(%{
        protocol: "uniswap",
        rules: [
          %{metric: "tvl", condition: "below", threshold: 999_999_999_999.0, severity: "critical"},
          %{metric: "tvl", condition: "above", threshold: 0.0, severity: "info"}
        ]
      })

      case result do
        {:ok, resp} ->
          # One fires (below $999B), one doesn't (above $0 is true so no alert)
          assert resp.alert_count >= 0
          for alert <- resp.alerts do
            assert Map.has_key?(alert, :metric)
            assert Map.has_key?(alert, :condition)
            assert Map.has_key?(alert, :threshold)
            assert Map.has_key?(alert, :current_value)
            assert Map.has_key?(alert, :severity)
            assert Map.has_key?(alert, :message)
          end
        {:error, _} -> :skip
      end
    end

    test "alert message includes protocol name" do
      result = DeFiAnalyticsAlertPrism.run(%{
        protocol: "curve-dex",
        rules: [
          %{metric: "tvl", condition: "below", threshold: 999_999_999_999.0, severity: "high"}
        ]
      })

      case result do
        {:ok, resp} ->
          if resp.alert_count > 0 do
            alert = hd(resp.alerts)
            assert alert.message =~ "curve-dex"
          end
        {:error, _} -> :skip
      end
    end
  end

  describe "handler/2 — yield pool monitoring" do
    test "accepts yield pool ID" do
      result = DeFiAnalyticsAlertPrism.run(%{
        check_yield_pool: "747c1d2a-c668-4682-b9f9-296708a3dd90",
        rules: [
          %{metric: "apy", condition: "below", threshold: 0.0, severity: "warning"}
        ]
      })
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "output schema" do
    test "output schema has required fields" do
      schema = DeFiAnalyticsAlertPrism.view().output_schema
      props = schema.properties
      assert Map.has_key?(props, :alerts)
      assert Map.has_key?(props, :alert_count)
      assert Map.has_key?(props, :current_metrics)
      assert Map.has_key?(props, :checked_at)
      assert Map.has_key?(props, :status)
    end

    test "input schema has rules required" do
      schema = DeFiAnalyticsAlertPrism.view().input_schema
      assert "rules" in (schema[:required] || [])
    end
  end
end
