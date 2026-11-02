defmodule Lux.YouTube.ContentCreation.ExperimentFrameworkTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentCreation.ExperimentFramework

  describe "create_experiment/3 and evaluate_results/3" do
    test "initializes experiment and declares statistically significant winner" do
      exp =
        ExperimentFramework.create_experiment(
          "Curiosity hook will outperform standard title",
          %{title: "Standard Guide", thumbnail_badge: "GUIDE"},
          %{title: "Why You Will Fail Without This", thumbnail_badge: "WARNING"}
        )

      assert exp.status == :draft
      assert exp.winner == :inconclusive

      # Simulate telemetry with clear winner B (CTR 8.5% vs 4.0%)
      telemetry_a = %{impressions: 3_000, clicks: 120, average_percentage_viewed: 42.0} # 4.0%
      telemetry_b = %{impressions: 3_000, clicks: 255, average_percentage_viewed: 48.0} # 8.5%

      evaluated = ExperimentFramework.evaluate_results(exp, telemetry_a, telemetry_b)

      assert evaluated.status == :concluded
      assert evaluated.winner == :variant_b
      assert evaluated.ctr_lift_percentage > 100.0
      assert evaluated.confidence_level_percentage >= 95.0
    end
  end
end
