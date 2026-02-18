# Telegram Analytics and Monitoring

Lux provides a comprehensive analytics and monitoring system for Telegram bots. This guide covers how to use the analytics engine, prisms, lenses, and visualization tools to track and analyze your bot's usage and performance.

## Overview

The Telegram Analytics system consists of:

- **Analytics Engine** (`Lux.Integrations.Telegram.Analytics`) — ETS-based core for collecting and storing metrics
- **Analytics Prisms** — Action-oriented modules for recording events and querying statistics
- **Analytics Lenses** — Read-only modules for viewing analytics dashboards and metrics
- **Visualization Helpers** — Tools for formatting analytics data into human-readable reports

## Quick Start

### Starting the Analytics Engine

The analytics engine runs as a GenServer with ETS tables for high-performance concurrent access:

```elixir
# Start the analytics engine
{:ok, _pid} = Lux.Integrations.Telegram.Analytics.start_link()

# Or with custom options
{:ok, _pid} = Lux.Integrations.Telegram.Analytics.start_link(
  max_events: 50_000,
  cleanup_interval_ms: 600_000
)
```

### Recording Events

#### Message Analytics

Track message events using the `MessageAnalytics` prism:

```elixir
alias Lux.Prisms.Telegram.Analytics.MessageAnalytics

# Record a sent message
MessageAnalytics.handler(%{
  action: "record",
  direction: "sent",
  chat_id: 123_456_789,
  user_id: 42,
  message_type: "text"
}, %{name: "MyBot"})

# Record a received message
MessageAnalytics.handler(%{
  action: "record",
  direction: "received",
  chat_id: 123_456_789,
  user_id: 42
}, %{name: "MyBot"})

# Get message statistics
{:ok, stats} = MessageAnalytics.handler(%{action: "stats"}, %{name: "MyBot"})
# => %{total_sent: 10, total_received: 5, total: 15, ...}
```

#### Command Usage

Track bot command executions:

```elixir
alias Lux.Prisms.Telegram.Analytics.CommandUsage

# Record a command execution
CommandUsage.handler(%{
  action: "record",
  command: "start",
  user_id: 42,
  response_time_ms: 150,
  success: true
}, %{name: "MyBot"})

# Get command statistics
{:ok, stats} = CommandUsage.handler(%{action: "stats"}, %{name: "MyBot"})
# => %{commands: %{"start" => %{count: 42, success_rate: 97.6, ...}}, most_used: "start"}
```

#### Error Monitoring

Track and analyze errors:

```elixir
alias Lux.Prisms.Telegram.Analytics.ErrorMonitoring

# Record an error
ErrorMonitoring.handler(%{
  action: "record",
  error_type: "api_error",
  message: "Rate limit exceeded",
  operation: "send_message"
}, %{name: "MyBot"})

# Get error statistics
{:ok, stats} = ErrorMonitoring.handler(%{action: "stats"}, %{name: "MyBot"})
# => %{total_errors: 5, error_rate: 2.5, errors_by_type: %{"api_error" => 3, ...}}
```

#### Performance Metrics

Track response times and throughput:

```elixir
alias Lux.Prisms.Telegram.Analytics.PerformanceMetrics

# Record a response time measurement
PerformanceMetrics.handler(%{
  action: "record",
  operation: "send_message",
  response_time_ms: 142
}, %{name: "MyBot"})

# Get performance statistics
{:ok, stats} = PerformanceMetrics.handler(%{action: "stats"}, %{name: "MyBot"})
# => %{avg_response_time_ms: 85.3, p95_response_time_ms: 250.0, ...}
```

### User Engagement Tracking

```elixir
alias Lux.Prisms.Telegram.Analytics.UserEngagement

# Track user activity
UserEngagement.handler(%{action: "track", user_id: 42}, %{name: "MyBot"})

# Get engagement metrics
{:ok, stats} = UserEngagement.handler(%{action: "stats"}, %{name: "MyBot"})
# => %{total_unique_users: 150, active_users_last_hour: 12, top_users: [...]}
```

### Usage Pattern Analysis

```elixir
alias Lux.Prisms.Telegram.Analytics.UsagePattern

{:ok, patterns} = UsagePattern.handler(%{action: "analyze"}, %{name: "MyBot"})
# => %{hourly_distribution: %{9 => 15, 10 => 23, ...}, peak_hour: 14, peak_day: :wednesday}
```

### Custom Metrics

Define and track your own metrics:

```elixir
alias Lux.Prisms.Telegram.Analytics.CustomMetric

# Define a custom metric
CustomMetric.handler(%{
  action: "define",
  name: "response_quality",
  type: "gauge",
  description: "User-rated response quality score"
}, %{name: "MyBot"})

# Record values
CustomMetric.handler(%{
  action: "record",
  name: "response_quality",
  value: 4.5
}, %{name: "MyBot"})

# Retrieve the value
{:ok, %{value: value}} = CustomMetric.handler(%{
  action: "get",
  name: "response_quality"
}, %{name: "MyBot"})

# List all custom metrics
{:ok, %{metrics: metrics}} = CustomMetric.handler(%{action: "list"}, %{name: "MyBot"})
```

## Dashboard and Reports

### Analytics Dashboard (Lens)

Use the `AnalyticsDashboard` lens for read-only access:

```elixir
alias Lux.Lenses.Telegram.AnalyticsDashboard

# Get full dashboard
{:ok, dashboard} = AnalyticsDashboard.focus(%{section: "all"})

# Get specific section
{:ok, msg_stats} = AnalyticsDashboard.focus(%{section: "messages"})
{:ok, cmd_stats} = AnalyticsDashboard.focus(%{section: "commands"})
```

### Metric Reader (Lens)

Read specific metrics and generate reports:

```elixir
alias Lux.Lenses.Telegram.MetricReader

# Read a custom metric
{:ok, %{value: value}} = MetricReader.focus(%{metric: "custom", name: "quality"})

# Generate formatted report
{:ok, %{report: report}} = MetricReader.focus(%{metric: "report"})

# Export all data
{:ok, export} = MetricReader.focus(%{metric: "export"})
```

### Metric Aggregation (Prism)

```elixir
alias Lux.Prisms.Telegram.Analytics.MetricAggregation

# Get full dashboard
{:ok, dashboard} = MetricAggregation.handler(%{action: "dashboard"}, %{name: "MyBot"})

# Export all data
{:ok, export} = MetricAggregation.handler(%{action: "export"}, %{name: "MyBot"})

# Reset all analytics data
{:ok, %{reset: true}} = MetricAggregation.handler(%{action: "reset"}, %{name: "MyBot"})
```

### Report Generator

Generate human-readable reports with visualizations:

```elixir
alias Lux.Prisms.Telegram.Analytics.ReportGenerator

# Full report
{:ok, %{report: report}} = ReportGenerator.handler(%{action: "full_report"}, %{name: "MyBot"})
IO.puts(report)

# Section-specific report
{:ok, %{report: report}} = ReportGenerator.handler(%{
  action: "section_report",
  section: "messages"
}, %{name: "MyBot"})
```

## Data Visualization

The `Visualization` module provides helpers for formatting data:

```elixir
alias Lux.Integrations.Telegram.Analytics.Visualization

# ASCII bar chart
chart = Visualization.bar_chart(%{
  "9:00" => 15,
  "10:00" => 23,
  "11:00" => 18,
  "12:00" => 30
}, title: "Hourly Messages", width: 25)

# Summary table
table = Visualization.summary_table(%{
  total_messages: 1500,
  active_users: 42,
  error_rate: 1.5
}, title: "Bot Summary")

# Sparkline
trend = Visualization.sparkline([5, 8, 12, 7, 15, 10, 20])
# => "▂▃▅▃▆▄█"

# Percentage bar
bar = Visualization.percentage_bar(85.0, width: 20)
# => "█████████████████░░░ 85.0%"

# Duration formatting
Visualization.format_duration(1500)   # => "1.5s"
Visualization.format_duration(42)     # => "42ms"
Visualization.format_duration(90_000) # => "1.5m"
```

## Architecture

### Storage

The analytics engine uses four ETS tables:

| Table | Type | Purpose |
|-------|------|---------|
| `:telegram_analytics_events` | ordered_set | Raw event log (time-series) |
| `:telegram_analytics_counters` | set | Atomic counters for metrics |
| `:telegram_analytics_gauges` | ordered_set | Point-in-time gauge values |
| `:telegram_analytics_custom` | ordered_set | Custom metric definitions and values |

### Event Types

| Event Type | Description |
|------------|-------------|
| `:message_sent` | Bot sent a message |
| `:message_received` | Bot received a message |
| `:message_forwarded` | Message was forwarded |
| `:message_edited` | Message was edited |
| `:message_deleted` | Message was deleted |
| `:command_executed` | Bot command was executed |
| `:callback_query` | Callback query received |
| `:inline_query` | Inline query received |
| `:error` | An error occurred |
| `:custom` | Custom event type |

### Data Flow

```
User/Bot Event → Prism Handler → Analytics Engine (ETS)
                                        ↓
                        Lens/Prism Query → Aggregated Metrics
                                        ↓
                        Visualization → Formatted Report
```

## Best Practices

1. **Start the analytics engine early** — Add it to your application's supervision tree
2. **Record events at the point of action** — Wrap your Telegram API calls with analytics recording
3. **Use custom metrics** for domain-specific tracking
4. **Monitor error rates** to catch issues early
5. **Review usage patterns** to optimize bot performance during peak hours
6. **Export data periodically** for long-term storage and analysis
