# Twitter Automation Guide

Automated engagement, scheduling, auto-reply, and follow management for Twitter.

## Tweet Scheduler

```elixir
{:ok, pid} = TweetScheduler.start_link()

# Schedule a tweet
{:ok, entry} = TweetScheduler.schedule(pid, %{
  text: "Hello Twitter!",
  scheduled_at: ~U[2026-03-09 12:00:00Z]
})

# Schedule a thread
TweetScheduler.schedule(pid, %{
  text: "Thread 1/3",
  scheduled_at: ~U[2026-03-09 12:00:00Z],
  thread: ["Thread 2/3", "Thread 3/3"]
})

# Get due tweets (ready to post)
{:ok, due} = TweetScheduler.get_due(pid)

# Content calendar
{:ok, calendar} = TweetScheduler.calendar(pid, {~D[2026-03-09], ~D[2026-03-15]})
```

## Engagement Rules

```elixir
{:ok, pid} = EngagementRules.start_link()

# Add rule: like crypto tweets from popular accounts
EngagementRules.add_rule(pid, %{
  name: "Crypto engagement",
  conditions: [{:keyword, ["bitcoin", "ethereum"]}, {:min_followers, 1000}],
  actions: [:like, :retweet],
  priority: 10
})

# Evaluate a tweet against all rules
{:ok, result} = EngagementRules.evaluate(pid, %{
  text: "Bitcoin hits new ATH!",
  author_followers: 50000,
  id: "123"
})
# result.actions => [:like, :retweet]

# Rate limiting
EngagementRules.set_rate_limit(pid, :like, 50)  # 50 likes per session
```

### Available Conditions
- `{:keyword, ["word1", "word2"]}` — text contains any keyword
- `{:min_followers, 1000}` — author has >= N followers
- `{:min_likes, 10}` — tweet has >= N likes
- `{:min_retweets, 5}` — tweet has >= N retweets
- `{:is_reply, false}` — is/isn't a reply
- `{:has_media, true}` — has media attachments
- `{:language, "en"}` — tweet language

## Auto-Reply

```elixir
{:ok, pid} = AutoReply.start_link(cooldown_seconds: 300)

# Add reply template
AutoReply.add_template(pid, %{
  keywords: ["help", "support"],
  reply_text: "Hi {{author}}, check our docs at https://docs.example.com!",
  priority: 5
})

# Find matching reply for a tweet
{:ok, reply} = AutoReply.find_reply(pid, %{
  text: "I need help with the API",
  author_id: "user1",
  author_name: "Alice"
})
# reply.reply_text => "Hi Alice, check our docs..."

# Block spammers
AutoReply.block_user(pid, "spammer_id")
```

## Follow Manager

```elixir
{:ok, pid} = FollowManager.start_link(daily_limit: 50)

# Queue follow/unfollow actions
FollowManager.queue_follow(pid, "user_id", :engagement_rule)
FollowManager.queue_unfollow(pid, "inactive_user", :inactive)

# Process queue
{:ok, pending} = FollowManager.get_pending(pid)
FollowManager.mark_done(pid, "user_id", :follow)

# Check stats
{:ok, stats} = FollowManager.stats(pid)
# %{following: 10, daily_count: 5, daily_limit: 50, ...}
```
