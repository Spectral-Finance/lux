# YouTube Community Manager

`Lux.Integrations.YouTube.CommunityManager` builds an offline community-management plan from
imported YouTube comments, subscriber events, channel goals, and campaign briefs.

```elixir
{:ok, report} =
  Lux.Prisms.YouTube.ManageCommunity.run(%{
    channel: "DeFi Operators",
    goals: ["increase qualified comments", "reduce spam"],
    comments: [
      %{id: "c1", author: "Mira", text: "Great breakdown. Can you cover wallets next?", likes: 12},
      %{id: "c2", author: "Bot", text: "Free giveaway click https://example.test now"}
    ],
    subscriber_events: [
      %{source: "community_post", segment: "returning viewer", hour: 14}
    ],
    campaigns: [
      %{name: "wallet week", goal: "comments", baseline: 20, current: 48, target: 80}
    ]
  })
```

The report includes:

- comment management and response queues;
- generated response suggestions;
- sentiment analysis and high-influence alerts;
- moderation queue, spam patterns, and policy rules;
- community post schedule;
- subscriber interaction patterns;
- cross-platform promotion assets;
- engagement campaign progress and next actions;
- fan interaction automation rules.

The module does not call the YouTube API. It is intended for imported channel exports,
webhook snapshots, analytics jobs, or agent memory.
