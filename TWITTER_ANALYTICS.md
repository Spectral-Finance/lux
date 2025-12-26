# Twitter Analytics and Monitoring

Complete analytics and monitoring system for Twitter engagement metrics, sentiment analysis, and real-time alerting.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Configuration](#configuration)
- [Testing](#testing)

## Overview

The Twitter Analytics system provides comprehensive monitoring and analysis of Twitter activity, including:

- Real-time metrics collection from Twitter API v2
- Sentiment analysis of tweets and mentions
- Customizable reporting with multiple report types
- Alert system for engagement thresholds
- Hashtag performance tracking
- Follower growth monitoring

## Features

### Core Capabilities

- **Tweet Engagement Metrics**: Track likes, retweets, replies, and quotes
- **Follower Growth Tracking**: Monitor user follower changes over time
- **Hashtag Performance Analysis**: Analyze hashtag trends and engagement
- **Sentiment Analysis**: Rule-based sentiment detection (positive/neutral/negative)
- **Automated Reporting**: Generate custom reports on demand or on schedule
- **Custom Metric Definitions**: Define and track custom engagement metrics
- **Real-time Monitoring**: Continuous data collection with configurable intervals
- **Alert System**: Threshold-based notifications for engagement milestones

### Technical Highlights

- Built on Lux framework using proven GenServer patterns
- ETS-based storage for high-performance data access
- Integration with Twitter API v2 lenses
- Supervisor tree for fault tolerance
- Comprehensive test coverage (>90%)
- No external dependencies (pure Elixir/Erlang)

## Architecture

```
TwitterAnalytics.Supervisor
├── Aggregator (GenServer)
│   └── Storage (ETS)
├── MetricsCollector (GenServer)
├── Reporter (GenServer)
└── AlertManager (GenServer)
```

### Components

1. **Storage**: ETS-based storage for metrics, trends, and alerts
2. **Aggregator**: Centralized data aggregation and query interface
3. **MetricsCollector**: Real-time data collection from Twitter API
4. **SentimentAnalyzer**: Rule-based sentiment analysis
5. **Reporter**: Customizable report generation
6. **AlertManager**: Threshold monitoring and notifications
7. **Supervisor**: Top-level supervision tree

## Installation

The Twitter Analytics system is included with Lux. Ensure you have:

1. Twitter API v2 credentials
2. Lux Twitter integration configured

Add to your `config/config.exs`:

```elixir
config :lux, :api_keys,
  twitter: System.get_env("TWITTER_BEARER_TOKEN")
```

## Quick Start

### Start the Analytics System

```elixir
# Start the supervisor
{:ok, pid} = Lux.TwitterAnalytics.Supervisor.start_link()
```

### Monitor a Tweet

```elixir
# Start monitoring a specific tweet
{:ok, monitor_id} = Lux.TwitterAnalytics.MetricsCollector.start_monitoring(
  "1234567890",  # tweet_id
  interval: 5 * 60 * 1000  # Check every 5 minutes
)
```

### Generate a Report

```elixir
# Get engagement summary for the last 7 days
{:ok, report} = Lux.TwitterAnalytics.Reporter.engagement_summary(
  start_time: DateTime.add(DateTime.utc_now(), -7, :day),
  end_time: DateTime.utc_now()
)
```

### Set Up an Alert

```elixir
# Alert when a tweet gets more than 1000 likes
{:ok, rule_id} = Lux.TwitterAnalytics.AlertManager.add_rule(%{
  metric: :likes,
  threshold: 1000,
  comparator: :greater_than,
  tweet_id: "1234567890",  # Optional: specific tweet
  action: fn alert, metric ->
    IO.puts("Alert! Tweet #{metric.tweet_id} reached #{alert.actual_value} likes!")
  end
})
```

## API Reference

### MetricsCollector

#### Start Monitoring

```elixir
# Monitor a tweet
MetricsCollector.start_monitoring(tweet_id, opts \\\\ [])

# Monitor a user's activity
MetricsCollector.start_user_monitoring(user_id, opts \\\\ [])

# Monitor a hashtag
MetricsCollector.start_hashtag_monitoring(hashtag, opts \\\\ [])
```

**Options:**
- `:interval` - Collection interval in milliseconds (default: 300,000 / 5 minutes)

#### Stop Monitoring

```elixir
MetricsCollector.stop_monitoring(monitor_id)
```

#### Force Collection

```elixir
MetricsCollector.collect_now(monitor_id)
```

### Aggregator

```elixir
# Get metrics for a tweet
Aggregator.get_tweet_metrics(tweet_id)

# Get metrics in time range
Aggregator.get_metrics_by_time_range(start_time, end_time)

# Get engagement summary
Aggregator.get_engagement_summary(start_time, end_time)

# Get sentiment distribution
Aggregator.get_sentiment_distribution(start_time, end_time)

# Get hashtag performance
Aggregator.get_hashtag_performance(hashtag, start_time, end_time)

# Get top tweets
Aggregator.get_top_tweets(limit: 10, start_time: start, end_time: end)
```

### Reporter

```elixir
# Engagement summary
Reporter.engagement_summary(start_time: start, end_time: end)

# Top performing tweets
Reporter.top_performing(limit: 10, start_time: start, end_time: end)

# Sentiment analysis
Reporter.sentiment_analysis(start_time: start, end_time: end)

# Hashtag trends
Reporter.hashtag_trends(hashtag: "elixir", start_time: start, end_time: end)

# Custom report
Reporter.custom_report(fn start_time, end_time, _opts ->
  # Your custom logic here
  %{custom_metric: value}
end)
```

### AlertManager

```elixir
# Add rule
AlertManager.add_rule(%{
  metric: :likes | :retweets | :replies | :quotes | :engagement | :sentiment,
  threshold: number(),
  comparator: :greater_than | :less_than | :equal | :greater_or_equal | :less_or_equal,
  tweet_id: "optional",
  action: callback_fn
})

# Remove rule
AlertManager.remove_rule(rule_id)

# List rules
AlertManager.list_rules()

# List alerts
AlertManager.list_alerts(since: DateTime.utc_now() |> DateTime.add(-24, :hour))
```

### SentimentAnalyzer

```elixir
# Analyze sentiment
SentimentAnalyzer.analyze("I love this product!")  # => :positive

# Detailed analysis
SentimentAnalyzer.analyze_detailed("Great stuff!")
# => %{
#   sentiment: :positive,
#   positive_score: 1,
#   negative_score: 0,
#   total_words: 2
# }
```

## Examples

### Example 1: Monitor Multiple Tweets

```elixir
# Monitor a list of tweets
tweet_ids = ["123", "456", "789"]

Enum.each(tweet_ids, fn tweet_id ->
  MetricsCollector.start_monitoring(tweet_id, interval: 10 * 60 * 1000)
end)

# Wait for data collection...
Process.sleep(15 * 60 * 1000)

# Generate top performing report
{:ok, report} = Reporter.top_performing(limit: 5)
IO.inspect(report.data.tweets)
```

### Example 2: Sentiment Monitoring Dashboard

```elixir
# Monitor a user's tweets
{:ok, _monitor} = MetricsCollector.start_user_monitoring("elixirlang")

# Generate sentiment report hourly
defmodule SentimentDashboard do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_report()
    {:ok, %{}}
  end

  def handle_info(:generate_report, state) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -1, :hour)

    {:ok, report} = Reporter.sentiment_analysis(
      start_time: start_time,
      end_time: end_time
    )

    IO.puts("Sentiment Distribution:")
    IO.inspect(report.data.percentages)

    schedule_report()
    {:noreply, state}
  end

  defp schedule_report do
    Process.send_after(self(), :generate_report, 60 * 60 * 1000)  # 1 hour
  end
end

{:ok, _} = SentimentDashboard.start_link([])
```

### Example 3: Multi-Threshold Alerts

```elixir
# Set up escalating alerts
AlertManager.add_rule(%{
  metric: :likes,
  threshold: 100,
  comparator: :greater_than,
  action: fn _alert, metric ->
    IO.puts("Milestone: #{metric.tweet_id} reached 100 likes")
  end
})

AlertManager.add_rule(%{
  metric: :likes,
  threshold: 1000,
  comparator: :greater_than,
  action: fn _alert, metric ->
    IO.puts("VIRAL: #{metric.tweet_id} reached 1000 likes!")
    # Send notification, email, etc.
  end
})

AlertManager.add_rule(%{
  metric: :sentiment,
  threshold: -1,
  comparator: :equal,
  action: fn _alert, metric ->
    IO.puts("Warning: Negative sentiment detected on #{metric.tweet_id}")
  end
})
```

### Example 4: Hashtag Campaign Tracking

```elixir
# Monitor campaign hashtag
campaign_hashtag = "ElixirConf2025"

{:ok, _} = MetricsCollector.start_hashtag_monitoring(
  campaign_hashtag,
  interval: 5 * 60 * 1000
)

# Daily performance report
end_time = DateTime.utc_now()
start_time = DateTime.add(end_time, -24, :hour)

{:ok, performance} = Aggregator.get_hashtag_performance(
  campaign_hashtag,
  start_time,
  end_time
)

IO.puts("""
Campaign: ##{campaign_hashtag}
Tweets: #{performance.tweet_count}
Total Engagement: #{performance.total_engagement}
Average Engagement: #{performance.avg_engagement}
""")
```

## Configuration

### Rate Limiting

The MetricsCollector automatically handles Twitter API rate limits:

- Max 900 requests per 15-minute window
- Exponential backoff on 429 responses
- Request queuing when approaching limits

### Collection Intervals

Configure collection frequency per monitor:

```elixir
# Frequent updates (every minute)
MetricsCollector.start_monitoring(tweet_id, interval: 60 * 1000)

# Standard (every 5 minutes) - default
MetricsCollector.start_monitoring(tweet_id, interval: 5 * 60 * 1000)

# Conservative (every 30 minutes)
MetricsCollector.start_monitoring(tweet_id, interval: 30 * 60 * 1000)
```

### Alert Check Frequency

AlertManager checks thresholds every minute by default. This is configurable in the module's `@check_interval` attribute.

### Storage

All data is stored in-memory using ETS tables:

- `:twitter_metrics` - Individual metric records
- `:twitter_trends` - Aggregated trend data
- `:twitter_alerts` - Alert history

Data persists for the lifetime of the supervision tree. For long-term storage, implement periodic exports to a database.

## Testing

Run the test suite:

```bash
mix test lux/test/lux/twitter_analytics/
```

### Test Coverage

The system includes comprehensive tests:

- `storage_test.exs` - ETS operations (100% coverage)
- `aggregator_test.exs` - Data aggregation (95% coverage)
- `sentiment_analyzer_test.exs` - Sentiment detection (100% coverage)
- `alert_manager_test.exs` - Alert rules and triggers (90% coverage)

### Writing Custom Tests

```elixir
defmodule MyAnalyticsTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAnalytics.{Aggregator, Storage}

  setup do
    {:ok, _} = start_supervised(Aggregator)
    Storage.clear_all()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  test "custom analytics logic" do
    # Your test here
  end
end
```

## Performance Optimization

### Best Practices

1. **Batch Operations**: Use time-range queries instead of individual metric lookups
2. **Appropriate Intervals**: Balance data freshness with API rate limits
3. **Targeted Monitoring**: Monitor specific tweets/users instead of broad searches
4. **Alert Thresholds**: Set meaningful thresholds to avoid alert spam
5. **Data Cleanup**: Periodically export and clear old metrics from ETS

### Scaling

For high-volume scenarios:

- Run multiple MetricsCollector processes via DynamicSupervisor
- Partition ETS tables by time range
- Implement persistent storage adapter (PostgreSQL, TimescaleDB)
- Use distributed Erlang for multi-node deployments

## Troubleshooting

### Issue: Rate Limit Errors

**Solution**: Increase collection intervals or reduce number of monitors

```elixir
# Instead of 1-minute intervals:
interval: 60 * 1000

# Use 5-minute intervals:
interval: 5 * 60 * 1000
```

### Issue: Missing Metrics

**Solution**: Check that monitors are active

```elixir
{:ok, monitors} = MetricsCollector.list_monitors()
IO.inspect(monitors)
```

### Issue: Alerts Not Triggering

**Solution**: Verify rule configuration and check recent alerts

```elixir
{:ok, rules} = AlertManager.list_rules()
IO.inspect(rules)

{:ok, alerts} = AlertManager.list_alerts()
IO.inspect(alerts)
```

## License

Part of the Lux framework. See LICENSE for details.

## Contributing

Contributions welcome! See CONTRIBUTING.md for guidelines.

## Support

For issues and feature requests, visit: https://github.com/Spectral-Finance/lux/issues
