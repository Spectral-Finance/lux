# Twitter Analytics And Monitoring

`Lux.Integrations.Twitter.AnalyticsMonitor` builds deterministic Twitter/X analytics
reports from metrics collected by an API client, stream processor, or exported dataset. It
does not require a bearer token in tests.

## Example

```elixir
{:ok, report} =
  Lux.Prisms.Twitter.GenerateAnalyticsReport.run(%{
    account: "@lux_ai",
    period_days: 14,
    thresholds: %{
      engagement_rate_min: 0.04,
      negative_sentiment_rate_max: 0.2,
      follower_growth_rate_min: 0.02
    },
    report_sections: ["metrics", "followers", "hashtags", "sentiment", "alerts"],
    custom_metrics: [
      %{name: "Reposts per 1k impressions", formula: "reposts_per_1k_impressions"}
    ],
    follower_snapshots: [
      %{date: "2026-05-01", followers: 10_000, following: 120, tweet_count: 500},
      %{date: "2026-05-14", followers: 10_850, following: 125, tweet_count: 524}
    ],
    tweets: [
      %{
        id: "tweet-1",
        text: "Shipping agent analytics #ai #agents",
        published_at: "2026-05-12",
        impressions: 45_000,
        likes: 1_200,
        reposts: 180,
        replies: 85,
        quotes: 40,
        bookmarks: 220,
        url_clicks: 310
      }
    ],
    mentions: [
      %{author: "builder", author_followers: 12_000, text: "Great launch, very useful"}
    ]
  })

report.metrics_collection.rates.engagement_rate
report.alert_system.status
report.automated_report.summary
```

## Report Sections

- `metrics_collection`: normalized tweet metrics, totals, rates, top tweets, and data quality notes.
- `data_aggregation`: in-memory storage snapshot, day buckets, hashtag buckets, and query indexes.
- `follower_growth`: follower delta, growth rate, direction, and daily growth velocity.
- `hashtag_performance`: hashtag usage, impressions, engagements, engagement rate, and recommendations.
- `mention_sentiment`: deterministic mention sentiment counts, negative mention rate, and review queue.
- `real_time_monitoring`: latest tweets, trend direction, current velocity, and monitoring checks.
- `alert_system`: engagement, sentiment, and follower-growth threshold alerts.
- `custom_reporting`: selected report sections and supported custom metrics.
- `automated_report`: dashboard-ready summary, scorecard, alerts, and report sections.
