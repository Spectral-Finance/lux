# Twitter Analytics and Monitoring Guide

Track engagement, analyze sentiment, monitor follower growth, and set up alerts.

## Metrics Collector

```elixir
{:ok, pid} = MetricsCollector.start_link()

# Track tweets
MetricsCollector.track_tweet(pid, %{id: "123", text: "Hello #elixir!", likes: 50, retweets: 20, replies: 5, quotes: 2, impressions: 3000})

# Track followers
MetricsCollector.track_follower_count(pid, 10500)

# Track mentions
MetricsCollector.track_mention(pid, %{text: "Thanks @mybot!", user_id: "u1"})

# Get overview
{:ok, overview} = MetricsCollector.get_overview(pid)
# %{total_tweets: 1, total_engagement: 130, avg_engagement: 130.0, follower_count: 10500, ...}

# Top tweets
{:ok, top} = MetricsCollector.get_top_tweets(pid, %{sort_by: :likes, limit: 5})

# Hashtag performance
{:ok, hashtags} = MetricsCollector.get_hashtag_stats(pid)
```

## Sentiment Analysis

```elixir
# Single text
result = SentimentAnalyzer.analyze("This product is amazing!")
# %{sentiment: :positive, score: 0.2, positive_count: 1, ...}

# Batch analysis
summary = SentimentAnalyzer.analyze_batch(["Great!", "Terrible", "OK"])
# %{total: 3, positive: 1, negative: 1, neutral: 1, distribution: %{...}}
```

## Alert System

```elixir
{:ok, pid} = AlertSystem.start_link()

# Define alerts
AlertSystem.add_alert(pid, %{name: "Viral tweet", metric: :likes, operator: :gte, threshold: 1000})
AlertSystem.add_alert(pid, %{name: "Low engagement", metric: :engagement, operator: :lt, threshold: 5})

# Check against current metrics
{:ok, triggered} = AlertSystem.check(pid, %{likes: 1500, engagement: 3})
# [%{alert_name: "Viral tweet", value: 1500, ...}, %{alert_name: "Low engagement", value: 3, ...}]
```

## Reports

```elixir
# Full analytics report
{:ok, report} = ReportGenerator.generate(collector_pid, %{top_n: 10})
# %{overview: ..., top_tweets: [...], top_hashtags: [...], follower_trend: ...}

# Sentiment report
{:ok, sentiment} = ReportGenerator.sentiment_report(mention_texts)
```
