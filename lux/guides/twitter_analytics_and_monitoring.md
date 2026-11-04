# Twitter Analytics and Monitoring in Lux

Lux provides high-performance Twitter analytics and real-time monitoring capabilities, enabling autonomous agents to measure tweet engagement, evaluate community sentiment, track follower velocity, audit hashtag reach, trigger anomaly alerts, and compile automated executive reports.

---

## 1. System Architecture

```
+-------------------------------------------------------------------------+
|                  TwitterAnalyticsPipelineBeam (Pipeline)                |
|                                                                         |
|  1. Collect Metrics  -->  2. Sentiment  -->  3. Hashtags  -->  4. Alerts  -->  5. Report |
+------------------------------------+------------------------------------+
                                     |
       +-----------------------------+-----------------------------+
       |                             |                             |
       v                             v                             v
+---------------+            +---------------+             +---------------+
|    Metrics    |            |   Sentiment   |             |    Hashtag    |
|   Collector   |            |   Analyzer    |             |   Aggregator  |
+---------------+            +---------------+             +---------------+
       |                             |                             |
       +-----------------------------+-----------------------------+
                                     |
                                     v
                        +-------------------------+
                        |   Alerts & Reporting    |
                        | (Thresholds, Markdown)  |
                        +-------------------------+
```

---

## 2. Real-Time Metrics Collection (`MetricsCollector`)

Calculates engagement rates and historical progression across key tweet metrics:

```elixir
# Collect engagement stats
{:ok, metrics} = Lux.Twitter.Analytics.MetricsCollector.collect_tweet_metrics("189283749281734912", %{
  impressions: 12_500,
  likes: 450,
  retweets: 180,
  replies: 35,
  quotes: 22,
  bookmarks: 85
})

# metrics.engagement_rate => 6.18%
```

---

## 3. Sentiment Analysis of Mentions (`Sentiment`)

Scans community replies and brand mentions for polarity (-1.0 to 1.0) and classification:

```elixir
# Analyze a single mention
res = Lux.Twitter.Analytics.Sentiment.analyze_text("This new Lux agent release is amazing and innovative!")
# res.classification => :positive
# res.polarity => 1.0

# Batch aggregate sentiment
stats = Lux.Twitter.Analytics.Sentiment.aggregate_sentiment([
  "Bullish on Lux agents and workflow beams!",
  "Great update, love the speed",
  "Experiencing a minor timeout bug"
])
```

---

## 4. Hashtag Analysis & Custom Metrics (`Aggregator`)

Analyzes multi-tweet hashtag reach, viral coefficients, and interaction indexes:

```elixir
# Aggregate hashtag metrics
stats = Lux.Twitter.Analytics.Aggregator.analyze_hashtags([
  %{hashtags: ["Lux", "AutonomousAgents"], impressions: 15_000, engagements: 850}
])

# Calculate custom viral metrics
custom = Lux.Twitter.Analytics.Aggregator.calculate_custom_metrics(%{
  impressions: 25_000,
  retweets: 350,
  likes: 1200,
  replies: 80
})
```

---

## 5. Threshold Alert System (`AlertSystem`)

Scans for engagement spikes and sentiment anomalies:

```elixir
alerts = Lux.Twitter.Analytics.AlertSystem.evaluate_alerts(metrics, sentiment_summary, %{
  viral_engagement_rate: 8.0,
  negative_sentiment_ratio: 0.25
})
```

---

## 6. Report Generator (`ReportGenerator`)

Formats executive summaries in Markdown and structured JSON:

```elixir
markdown = Lux.Twitter.Analytics.ReportGenerator.generate_markdown_report(metrics, sentiment, hashtags, alerts)
json = Lux.Twitter.Analytics.ReportGenerator.generate_json_report(metrics, sentiment, hashtags, alerts)
```

---

## 7. Pipeline Orchestration Beam

Run the full end-to-end pipeline in Lux agents:

```elixir
{:ok, result} = Lux.Beams.Twitter.TwitterAnalyticsPipelineBeam.run(%{
  tweet_id: "189283749281734912",
  mentions: [
    "Amazing release, congratulations team!",
    "Bullish on autonomous agent workflows!"
  ],
  tweets: [
    %{hashtags: ["Lux", "Elixir", "AI"], impressions: 10_000, engagements: 450}
  ]
})
```
