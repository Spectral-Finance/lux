# Twitter Automation Engagement Guide

Lux can plan Twitter/X engagement without making network calls. The planner
turns content drafts, audience mentions, engagement rules, and queue limits into
an auditable execution plan for a separate publisher or human reviewer.

## Capabilities

The planner covers four workflow areas:

* Content scheduling with validation for empty posts and the 280 character limit.
* Rule-based engagement for replies, likes, follows, reposts, and DM review steps.
* Queue management with hourly caps, minimum spacing, quiet hours, and dedupe keys.
* Per-surface policy for tweet writes, engagement writes, relationship actions,
  DMs, and manual review work.
* Moderation output for risky content and actions that should not be auto-sent.

## Basic Usage

```elixir
alias Lux.Prisms.Twitter.Automation.PlanEngagement

{:ok, plan} =
  PlanEngagement.handler(
    %{
      now: "2026-06-06T09:00:00Z",
      content_calendar: [
        %{
          id: "launch-thread",
          text: "Lux agents can coordinate content, engagement, and review queues.",
          campaign: "agent-launch",
          tags: ["lux", "automation"],
          priority: 80
        }
      ],
      mentions: [
        %{
          id: "mention-1",
          author: "builder",
          text: "Can Lux help plan Twitter automation?",
          followers: 2500,
          received_at: "2026-06-06T09:05:00Z"
        }
      ],
      rules: [
        %{
          id: "reply-builders",
          type: "auto_reply",
          keywords: ["lux", "automation"],
          reply_template: "Thanks {{author}}, here is a Lux engagement plan.",
          priority: 70
        }
      ],
      queue_policy: %{
        max_actions_per_hour: 12,
        min_spacing_seconds: 300,
        quiet_hours: %{start_hour: 22, end_hour: 7},
        surface_limits: %{
          "tweet_write" => %{max_actions_per_hour: 8, backoff_seconds: 900},
          "relationship_write" => %{max_actions_per_hour: 4, requires_review: true},
          "dm_write" => %{max_actions_per_hour: 2, requires_review: true}
        }
      }
    },
    %{name: "SocialAgent"}
  )

plan.queue
```

## Rule Types

Rules use a small set of stable action types:

* `auto_reply` or `reply` creates a prepared reply.
* `engage_keyword` or `like` creates a like action.
* `follow_candidate` creates a follow action when `min_followers` is satisfied.
* `repost` or `retweet` creates a repost action.
* `dm_sequence` creates a DM draft marked `needs_review`.

Rules match when all follower limits pass and any configured keyword is found in
the mention text. Empty keyword lists match all mentions, which is useful for
follower-only rules.

## Queue Policy

`queue_policy` controls execution timing:

* `max_actions_per_hour` caps the number of queued actions in each hour bucket.
* `min_spacing_seconds` spaces each queued action from the prior item.
* `quiet_hours` shifts actions away from disallowed hours.
* `duplicate_window_minutes` is included for downstream executors that use the
  generated `dedupe_key`.
* `surface_limits` can override each Twitter/X API surface with a separate
  `max_actions_per_hour`, `access_tier`, `backoff_seconds`, and
  `requires_review` setting.

Default surfaces are:

* `tweet_write` for posts and replies.
* `engagement_write` for likes and reposts.
* `relationship_write` for follows.
* `dm_write` for DMs.
* `manual_review` for unknown or unsupported actions.

## Safety Review

The planner does not send posts, replies, follows, or DMs. It only produces a
plan. Posts with empty text or more than 280 characters are rejected. Engagements
containing spam-like terms are marked `needs_review`, and DM sequence rules are
always routed to review so applications can require explicit approval before
contacting users privately.

Downstream integrations should only execute items from `plan.queue` and should
keep `plan.moderation` visible to operators.
