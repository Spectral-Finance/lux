defmodule Lux.Prisms.YouTubeGrowthEnginePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.YouTubeGrowthEnginePrism

  describe "handler/2" do
    test "executes track_metrics action" do
      {:ok, response} =
        YouTubeGrowthEnginePrism.run(%{
          action: "track_metrics",
          payload: %{views: 20_000, estimated_revenue_usd: 120.0}
        })

      assert response.action == "track_metrics"
      assert response.result.rpm == 6.0
    end

    test "executes predict_growth action" do
      {:ok, response} =
        YouTubeGrowthEnginePrism.run(%{
          action: "predict_growth",
          payload: %{current_subscribers: 5_000, daily_sub_velocity: 20.0}
        })

      assert response.action == "predict_growth"
      assert response.result.projected_30d.projected_subscribers > 5_000
    end

    test "executes plan_midrolls action" do
      {:ok, response} =
        YouTubeGrowthEnginePrism.run(%{
          action: "plan_midrolls",
          payload: %{duration_seconds: 600}
        })

      assert response.action == "plan_midrolls"
      assert response.result.eligible_for_midrolls == true
    end

    test "executes audit_channel action" do
      {:ok, response} =
        YouTubeGrowthEnginePrism.run(%{
          action: "audit_channel",
          payload: %{channel_name: "Audit Test", average_ctr: 5.2}
        })

      assert response.action == "audit_channel"
      assert response.result.overall_score > 0
    end

    test "executes calculate_roi action" do
      {:ok, response} =
        YouTubeGrowthEnginePrism.run(%{
          action: "calculate_roi",
          payload: %{
            campaign_id: "Vid_1",
            costs: %{video_editing_usd: 100.0},
            revenue: 300.0
          }
        })

      assert response.action == "calculate_roi"
      assert response.result.roi_multiplier == 3.0
    end

    test "executes executive_audit action" do
      {:ok, response} =
        YouTubeGrowthEnginePrism.run(%{
          action: "executive_audit",
          payload: %{
            channel_name: "Agency Lux",
            views: 10_000,
            estimated_revenue_usd: 50.0
          }
        })

      assert response.action == "executive_audit"
      assert response.result.status == :audit_complete
      assert is_binary(response.result.executive_markdown_report)
    end

    test "handles unknown action with descriptive error" do
      {:error, reason} =
        YouTubeGrowthEnginePrism.run(%{
          action: "unsupported_growth_action",
          payload: %{}
        })

      assert String.contains?(reason, "Unknown action: unsupported_growth_action")
    end
  end

  describe "schema validation" do
    test "validates prism definition and schema" do
      prism = YouTubeGrowthEnginePrism.view()
      assert prism.name == "YouTube Growth Engine Prism"
      assert prism.input_schema.required == ["action"]
      assert Map.has_key?(prism.input_schema.properties, :action)
      assert Map.has_key?(prism.input_schema.properties, :payload)
      assert prism.output_schema.required == ["action", "result"]
    end
  end
end
