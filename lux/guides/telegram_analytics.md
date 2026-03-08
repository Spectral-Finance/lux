# Telegram Analytics and Monitoring Guide

Track and analyze your Telegram bot's performance, engagement, and usage patterns.

## Architecture

```
Messages → Collector (GenServer) → Aggregator → AnalyticsReport (Prism)
                                                  GetBotMetrics (Lens)
```

## Quick Start

```elixir
# Start the collector
{:ok, pid} = Lux.Integrations.Telegram.Analytics.Collector.start_link()

# Track events
Collector.track_message(pid, %{from_id: user_id, chat_id: chat_id, has_media: false})
Collector.track_command(pid, "/start", user_id, chat_id)
Collector.track_error(pid, :timeout, %{endpoint: "/sendMessage"})
Collector.track_response_time(pid, "/sendMessage", 45)

# Get analytics
{:ok, counters} = Collector.get_counters(pid)
# => %{messages_total: 100, unique_users: 25, errors_total: 3, ...}
```

## Reports via Prism

```elixir
# Full report
AnalyticsReport.handler(%{action: "full_report", collector_pid: pid}, nil)
# => %{overview: ..., performance: ..., engagement: ..., errors: ..., patterns: ...}

# Specific reports
AnalyticsReport.handler(%{action: "errors", collector_pid: pid}, nil)
AnalyticsReport.handler(%{action: "engagement", collector_pid: pid}, nil)
AnalyticsReport.handler(%{action: "patterns", collector_pid: pid}, nil)
```

## Metrics

### Performance
- Average, P50, P95, P99 response times
- Min/max latency tracking

### Engagement
- Messages per user
- Messages per chat
- Command usage rate
- Unique users/chats

### Error Analysis
- Error rate (errors / total messages)
- Errors by type breakdown
- Trend tracking

### Usage Patterns
- Hourly message distribution
- Peak hours identification
- Top commands ranking

## Bot Metrics (Telegram API)

```elixir
# Webhook status
GetBotMetrics.focus(%{action: "webhook_info", token: bot_token})
# => %{url: "...", pending_update_count: 3, ...}

# Bot info
GetBotMetrics.focus(%{action: "bot_info", token: bot_token})
# => %{username: "my_bot", supports_inline_queries: true, ...}
```
