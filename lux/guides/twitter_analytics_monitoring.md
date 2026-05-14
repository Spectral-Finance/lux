# Twitter Analytics and Monitoring

Lux now includes a transport-neutral analytics core for Twitter/X engagement data. The implementation accepts normalized tweet, follower, and mention records and produces:

- tweet engagement totals and rates
- follower growth deltas
- hashtag performance rankings
- deterministic mention sentiment rollups
- alert threshold evaluations
- dashboard-ready chart payloads

The analytics layer does not call the Twitter/X API or require credentials. API clients, webhooks, exports, or scheduled collectors can feed normalized events into `Lux.Integrations.Twitter.Analytics`.

## Prisms

- `Lux.Prisms.Twitter.EngagementReportPrism` builds a complete report.
- `Lux.Prisms.Twitter.EngagementAlertPrism` returns only alerts and a summary.
- `Lux.Prisms.Twitter.ReportPayloadPrism` returns dashboard chart payloads and top hashtags.

## Example

```elixir
Lux.Prisms.Twitter.EngagementReportPrism.run(%{
  tweets: [
    %{
      id: "tweet-1",
      hashtags: ["Lux"],
      metrics: %{likes: 100, replies: 10, reposts: 20, quotes: 5, impressions: 2_000}
    }
  ],
  followers: [
    %{captured_at: "2026-05-07", followers: 200},
    %{captured_at: "2026-05-14", followers: 250}
  ],
  mentions: [%{text: "great work"}],
  thresholds: %{min_engagement_rate: 0.02}
})
```

The result contains engagement, follower growth, hashtag, sentiment, alert, chart, and summary sections suitable for agent workflows or dashboards.
