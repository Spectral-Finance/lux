# Telegram Analytics and Monitoring in Lux

## Overview

The `Lux.Integrations.Telegram.Analytics` suite provides complete observational intelligence, usage analytics, health monitoring, and visual reporting for Telegram bots and community ecosystems:

- **Telemetry Event Collection**: Captures structured message, command, callback query, error, and API latency events.
- **Message Volume & Throughput**: Tracks message counts, message type distributions (text, photo, audio, poll, etc.), chat type shares, and messages-per-hour metrics.
- **User Engagement & Retention**: Measures unique active users (DAU/WAU), interaction frequencies, and generates user/chat activity leaderboards.
- **Command Usage Statistics**: Breakdown of command invocations, success/failure rates, average execution latencies, and parameter patterns.
- **Performance & Health Monitoring**: Calculates response latency percentiles (p50, p90, p95, p99), error rates, 429 rate limit counts, and triggers anomaly threshold alerts.
- **Temporal Usage Patterns**: Analyzes peak activity hours (UTC), quiet hours, day-of-week trends, and audience activity cycles.
- **Data Visualization & Reporting**: Built-in ASCII/Unicode bar charts (`█▓▒░`), sparklines (` ▂▃▅▆▇`), progress meters, and executive Markdown/HTML report generators.
- **Prisms & Beams**: 5 specialized Prisms and the automated `Lux.Beams.Telegram.AnalyticsBeam` pipeline.

---

## Architecture

```
                       +---------------------------------------+
                       |      Telegram Interactions / Events   |
                       +---------------------------------------+
                                           |
                                           v
                       +---------------------------------------+
                       |           Analytics Collector         |
                       +---------------------------------------+
                                           |
        +----------------------------------+----------------------------------+
        |                                  |                                  |
        v                                  v                                  v
+------------------+             +--------------------+            +--------------------+
|  MessageTracker  |             | EngagementTracker  |            |    CommandStats    |
| - Message volume |             | - Active users     |            | - Frequencies      |
| - Throughput/hr  |             | - Leaderboards     |            | - Latency / cmd    |
| - Media breakdown|             | - Actions / user   |            | - Success rates    |
+------------------+             +--------------------+            +--------------------+
        |                                  |                                  |
        +----------------------------------+----------------------------------+
                                           |
        +----------------------------------+----------------------------------+
        |                                                                     |
        v                                                                     v
+------------------+                                                +--------------------+
|PerformanceMonitor|                                                |UsagePatternAnalyzer|
| - Latency p50-p99|                                                | - Peak hours (UTC) |
| - Error rates    |                                                | - Busiest day      |
| - 429 rate limits|                                                | - Hourly heatmaps  |
+------------------+                                                +--------------------+
        |                                                                     |
        +----------------------------------+----------------------------------+
                                           |
                                           v
                       +---------------------------------------+
                       |            ReportGenerator            |
                       | - Markdown & HTML formatted reports   |
                       | - ASCII bar charts, sparklines, meters|
                       +---------------------------------------+
```

---

## 1. Telemetry Event Collection

The `Collector` captures structured interaction records:

```elixir
alias Lux.Integrations.Telegram.Analytics.Collector

state = Collector.init(max_events: 50_000)

# Record incoming command event with latency:
{:ok, state, event} =
  Collector.record_event(state, :command, %{
    command: "swap",
    chat_id: -1001234567,
    user_id: 998877,
    chat_type: "supergroup",
    latency_ms: 145,
    status: :success
  })

# Record API error:
{:ok, state, _} =
  Collector.record_event(state, :error, %{
    chat_id: -1001234567,
    status: :error,
    error_code: 429,
    error_message: "Too Many Requests: retry after 5"
  })

# Query events:
recent_errors = Collector.query_events(state, %{status: :error})
```

---

## 2. Message & Throughput Analytics

`MessageTracker` analyzes volume and message classifications:

```elixir
alias Lux.Integrations.Telegram.Analytics.MessageTracker

stats = MessageTracker.analyze(events)

stats.total_messages       #=> 12,450
stats.messages_per_hour    #=> 518.75
stats.type_distribution    #=> %{text: 9200, photo: 1800, document: 450, poll: 200, ...}
stats.chat_distribution    #=> %{"supergroup" => 10200, "private" => 2250}
```

---

## 3. User Engagement & Community Leaderboards

```elixir
alias Lux.Integrations.Telegram.Analytics.EngagementTracker

engagement = EngagementTracker.analyze(events)

engagement.unique_active_users       #=> 1,420
engagement.average_actions_per_user  #=> 8.76
engagement.top_active_users          #=> [%{user_id: 111, action_count: 340}, ...]
engagement.top_active_chats          #=> [%{chat_id: -100123, message_count: 5120}, ...]
```

---

## 4. Command Usage Statistics

```elixir
alias Lux.Integrations.Telegram.Analytics.CommandStats

cmd_stats = CommandStats.analyze(events)

cmd_stats.total_command_invocations #=> 3,890
cmd_stats.distinct_commands_used    #=> 14

# Breakdown per command:
hd(cmd_stats.commands)
#=> %{
#     command: "swap",
#     invocations: 1850,
#     success_count: 1820,
#     failure_count: 30,
#     success_rate: 98.4,
#     avg_latency_ms: 135.2
#   }
```

---

## 5. Performance Monitoring & Anomaly Alerts

Computes latency percentiles and triggers alerts when thresholds are breached:

```elixir
alias Lux.Integrations.Telegram.Analytics.PerformanceMonitor

thresholds = %{
  max_error_rate_percent: 3.0,
  max_p95_latency_ms: 1500,
  max_rate_limit_errors: 5
}

perf = PerformanceMonitor.analyze(events, thresholds)

perf.error_rate_percent    #=> 0.45%
perf.latency.p50           #=> 85ms
perf.latency.p95           #=> 320ms
perf.latency.p99           #=> 780ms
perf.rate_limit_429_count  #=> 0
perf.alerts                #=> [] (empty if healthy)
```

---

## 6. Usage Patterns & Peak Hours

```elixir
alias Lux.Integrations.Telegram.Analytics.UsagePatternAnalyzer

patterns = UsagePatternAnalyzer.analyze(events)

patterns.peak_hour_utc   #=> 15 (3 PM UTC)
patterns.quiet_hour_utc  #=> 4  (4 AM UTC)
patterns.busiest_day     #=> "Thursday"
```

---

## 7. Data Visualization Helpers & Reports

`ReportGenerator` provides lightweight ASCII visual rendering:

```elixir
alias Lux.Integrations.Telegram.Analytics.ReportGenerator

# ASCII Bar Chart:
ReportGenerator.ascii_bar_chart([{"swap", 150}, {"balance", 80}, {"help", 40}], 15)
#=>
# swap         | ███████████████ (150)
# balance      | ████████ (80)
# help         | ████ (40)

# Sparkline:
ReportGenerator.sparkline([10, 25, 40, 80, 60, 95, 30])
#=> " ▂▃▆▅█▂"

# Progress Bar:
ReportGenerator.progress_bar(84.2, 12)
#=> "[■■■■■■■■■■□□] 84.2%"

# Executive Markdown Report:
report_md = ReportGenerator.generate_markdown_report(combined_analytics)
```

---

## 8. Specialized Prisms Reference

| Prism | Module | Description |
|---|---|---|
| `CollectMetric` | `Lux.Prisms.Telegram.Analytics.CollectMetric` | Captures interaction events into structured telemetry |
| `AggregateMetrics` | `Lux.Prisms.Telegram.Analytics.AggregateMetrics` | Aggregates volume, user engagement, and command usage |
| `TrackPerformance` | `Lux.Prisms.Telegram.Analytics.TrackPerformance` | Measures latency percentiles (p50-p99) and error anomalies |
| `AnalyzeUsagePatterns` | `Lux.Prisms.Telegram.Analytics.AnalyzeUsagePatterns` | Identifies peak hours and day-of-week community trends |
| `GenerateReport` | `Lux.Prisms.Telegram.Analytics.GenerateReport` | Builds formatted Markdown/HTML reports with ASCII charts |

---

## 9. AnalyticsBeam Pipeline

Connects metrics aggregation, performance monitoring, and report generation:

```elixir
alias Lux.Beams.Telegram.AnalyticsBeam

{:ok, result} = AnalyticsBeam.analyze_events(telemetry_events, format: "markdown")

result.metrics      # Combined volume, engagement, command stats
result.performance  # Latency percentiles & anomaly alerts
result.patterns     # Peak hours & temporal patterns
result.report       # Formatted Markdown report with ASCII bar charts
```
