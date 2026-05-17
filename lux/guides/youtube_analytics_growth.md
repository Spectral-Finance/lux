# YouTube Analytics Growth

`Lux.Integrations.YouTube.AnalyticsGrowth` provides deterministic, transport-neutral helpers for YouTube channel analytics. It accepts normalized snapshots from any collector and returns metrics that Lux agents can use without requiring live YouTube API access in tests.

## Features

- Engagement, subscriber conversion, retention, ROI, and RPM calculations
- Ordered growth trends for views, subscribers, and revenue
- Competitor benchmarking against normalized snapshots
- Conservative linear forecasts for future periods
- Revenue optimization estimates with target RPM and subscriber-conversion goals
- Channel audit checks with actionable recommendations
- `Lux.Prisms.YouTube.AnalyzeGrowth` for agent workflows

## Example

```elixir
alias Lux.Integrations.YouTube.AnalyticsGrowth

report =
  AnalyticsGrowth.report(
    [
      %{views: 1_000, subscribers: 100, revenue: 80, cost: 40},
      %{
        views: 1_500,
        subscribers: 130,
        revenue: 120,
        cost: 60,
        average_view_duration_seconds: 180,
        video_duration_seconds: 300
      }
    ],
    [%{views: 1_200, likes: 30, comments: 10, shares: 5}],
    forecast_periods: 3,
    target_rpm: 100
  )

report.summary
report.forecast
report.revenue_optimization
```

## Agent prism

```elixir
Lux.Prisms.YouTube.AnalyzeGrowth.run(%{
  channel_series: [%{views: 1_000}, %{views: 1_500}],
  forecast_periods: 2
})
```
