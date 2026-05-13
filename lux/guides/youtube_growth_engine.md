# YouTube Growth Engine

`Lux.Integrations.YouTube.GrowthEngine` builds a deterministic analytics and growth report
from imported YouTube channel data. It does not call the YouTube API directly; pass metrics
from YouTube Studio exports, internal dashboards, or another ingestion job.

## Example

```elixir
{:ok, report} =
  Lux.Prisms.YouTube.AnalyzeGrowth.run(%{
    channel_name: "DeFi Operators",
    period_days: 28,
    production_cost_usd: 1_800,
    goals: %{views: 50_000, subscribers: 1_000, revenue_usd: 1_500},
    videos: [
      %{
        title: "Stablecoin risk checklist",
        published_at: "2026-05-01",
        views: 18_000,
        impressions: 240_000,
        average_view_duration_seconds: 310,
        duration_seconds: 620,
        subscribers_gained: 360,
        revenue_usd: 540,
        topics: ["stablecoins", "risk"],
        traffic_sources: %{"browse" => 0.46, "search" => 0.28, "external" => 0.12},
        audience: %{"US" => 0.42, "SG" => 0.18, "UK" => 0.12}
      }
    ],
    competitors: [
      %{channel: "Protocol Brief", views: 42_000, subscribers_gained: 640, upload_count: 4}
    ]
  })

report.analytics_data_collection.totals.views
report.growth_prediction.projected_revenue_usd
report.automated_report.alerts
```

## Report Sections

- `analytics_data_collection`: normalized video rows, totals, CTR, retention, RPM, subscriber conversion, top videos, and data quality notes.
- `audience_insights`: top topics, weighted traffic sources, audience segments, and audience recommendations.
- `trend_analysis`: recent-vs-prior view, revenue, and subscriber growth direction.
- `growth_prediction`: next-period views, subscribers, revenue, confidence, and assumptions.
- `revenue_optimization`: revenue gap, RPM priority, monetization opportunities, and tests.
- `retention_analysis`: weak-retention videos and suggested fixes.
- `competitor_analysis`: competitor view, subscriber, and upload benchmarks.
- `roi_tracking`: production cost, profit, ROI, and payback status.
- `channel_audit`: automated channel score, findings, recurring checks, and recommended focus.
- `automated_report`: a dashboard-ready summary, scorecard, alerts, and recurring report sections.
- `experiments`: CTR, retention, and RPM experiments tied to current baselines.
