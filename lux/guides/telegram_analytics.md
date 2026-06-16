# Telegram Analytics and Monitoring

Lux provides storage-agnostic Telegram analytics helpers and prisms for bot usage monitoring.

## Event Shape

```elixir
%{
  event_type: "message",
  chat_id: 123,
  user_id: 456,
  command: "/start",
  duration_ms: 32,
  ok: true,
  occurred_at: DateTime.utc_now(),
  metadata: %{bot: "support"}
}
```

## Record Events

```elixir
{:ok, %{events: events}} =
  Lux.Prisms.Telegram.Analytics.RecordEvent.run(%{
    events: [],
    event: %{
      event_type: "command",
      chat_id: 123,
      user_id: 456,
      command: "/status",
      duration_ms: 44,
      ok: true,
      occurred_at: "2026-06-15T10:00:00Z"
    }
  })
```

## Aggregate Metrics

```elixir
{:ok, %{metrics: metrics}} =
  Lux.Prisms.Telegram.Analytics.AggregateMetrics.run(%{events: events})

metrics.command_usage
metrics.error_rate
```

## Generate Reports

```elixir
{:ok, %{report: report}} =
  Lux.Prisms.Telegram.Analytics.GenerateReport.run(%{
    events: events,
    top_limit: 5
  })

report.chart_data.daily_usage
report.recommendations
```

The report includes chart-ready series for daily usage, hourly usage, and command usage. Applications can feed those series into dashboards without Lux dictating a visualization library.
