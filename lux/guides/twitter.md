# Twitter/X API Core Integration

Comprehensive Twitter API v2 integration for Lux, enabling authentication,
tweet management, user interactions, and content search.

## Overview

### Authentication
- **`Lux.Integrations.Twitter`** — Common auth settings
- **`Lux.Integrations.Twitter.Client`** — HTTP client with OAuth 1.0a & Bearer Token

### Lenses (Read Data)
- **`Lux.Lenses.Twitter.GetTweet`** — Fetch tweet by ID with metrics
- **`Lux.Lenses.Twitter.SearchTweets`** — Search recent tweets (7-day window)
- **`Lux.Lenses.Twitter.GetUser`** — User profile lookup (by ID or username)
- **`Lux.Lenses.Twitter.GetTimeline`** — User tweet timeline
- **`Lux.Lenses.Twitter.GetMentions`** — Tweets mentioning a user

### Prisms (Write Actions)
- **`Lux.Prisms.Twitter.Tweets.CreateTweet`** — Create tweet (text, media, poll, quote, reply)
- **`Lux.Prisms.Twitter.Tweets.DeleteTweet`** — Delete tweet
- **`Lux.Prisms.Twitter.Tweets.CreateThread`** — Create tweet thread
- **`Lux.Prisms.Twitter.Tweets.LikeTweet`** — Like/unlike
- **`Lux.Prisms.Twitter.Tweets.Retweet`** — Retweet/undo
- **`Lux.Prisms.Twitter.Tweets.Bookmark`** — Bookmark/remove
- **`Lux.Prisms.Twitter.Users.FollowUser`** — Follow/unfollow
- **`Lux.Prisms.Twitter.Users.MuteUser`** — Mute/unmute
- **`Lux.Prisms.Twitter.Users.BlockUser`** — Block/unblock

## Configuration

```elixir
# config/config.exs
config :lux, :api_keys,
  # For read-only endpoints (app-only access)
  twitter_bearer: System.get_env("TWITTER_BEARER_TOKEN"),
  # For write endpoints (user context)
  twitter_api_key: System.get_env("TWITTER_API_KEY"),
  twitter_api_secret: System.get_env("TWITTER_API_SECRET"),
  twitter_access_token: System.get_env("TWITTER_ACCESS_TOKEN"),
  twitter_access_secret: System.get_env("TWITTER_ACCESS_SECRET")
```

## Quick Start

### Post a Tweet

```elixir
{:ok, tweet} = Lux.Prisms.Twitter.Tweets.CreateTweet.handler(%{
  "text" => "Hello from Lux! 🤖"
}, nil)

IO.puts("Posted tweet: #{tweet.tweet_id}")
```

### Create a Thread

```elixir
{:ok, thread} = Lux.Prisms.Twitter.Tweets.CreateThread.handler(%{
  "tweets" => [
    "1/ Here's a thread about Lux...",
    "2/ It's a multi-agent framework in Elixir",
    "3/ With full Twitter integration! 🚀"
  ]
}, nil)

IO.puts("Thread created: #{length(thread.thread_ids)} tweets")
```

### Search Tweets

```elixir
{:ok, results} = Lux.Lenses.Twitter.SearchTweets.focus(%{
  query: "elixir lang -is:retweet",
  max_results: 20
})

for tweet <- results.tweets do
  IO.puts("[#{tweet.metrics.likes} ❤️] #{tweet.text}")
end
```

### Fetch User Profile

```elixir
{:ok, user} = Lux.Lenses.Twitter.GetUser.focus(%{username: "elikirf"})

IO.puts("#{user.name} (@#{user.username})")
IO.puts("Followers: #{user.metrics.followers}")
IO.puts("Bio: #{user.description}")
```

### Like, Retweet, Follow

```elixir
# Like a tweet
Lux.Prisms.Twitter.Tweets.LikeTweet.handler(%{
  "tweet_id" => "123456",
  "user_id" => "my_user_id"
}, nil)

# Retweet
Lux.Prisms.Twitter.Tweets.Retweet.handler(%{
  "tweet_id" => "123456",
  "user_id" => "my_user_id"
}, nil)

# Follow a user
Lux.Prisms.Twitter.Users.FollowUser.handler(%{
  "target_user_id" => "789",
  "user_id" => "my_user_id"
}, nil)
```

## Authentication Methods

### Bearer Token (App-Only)
Used by Lenses (read endpoints). Provides higher rate limits.
Set via `twitter_bearer` in `:api_keys` config.

### OAuth 1.0a (User Context)
Used by Prisms (write endpoints). Required for posting, liking, etc.
Requires all four OAuth credentials: API key, API secret, access token, access secret.

The client automatically generates HMAC-SHA1 signatures per the OAuth 1.0a spec.

## Rate Limits

The client tracks rate limit headers from every response:

```elixir
{:ok, %{data: data, rate_limit: %{remaining: 45, limit: 50, reset_at: 1700000000}}} =
  Lux.Integrations.Twitter.Client.request(:get, "/tweets/123", %{token: "..."})
```

When rate limited, the client returns `{:error, {:rate_limited, reset_timestamp}}`.

## Agent Integration

```elixir
defmodule MyTwitterAgent do
  use Lux.Agent,
    name: "Twitter Bot",
    goal: "Monitor and engage on Twitter",
    tools: [
      Lux.Lenses.Twitter.SearchTweets,
      Lux.Lenses.Twitter.GetTweet,
      Lux.Lenses.Twitter.GetUser,
      Lux.Lenses.Twitter.GetTimeline,
      Lux.Lenses.Twitter.GetMentions,
      Lux.Prisms.Twitter.Tweets.CreateTweet,
      Lux.Prisms.Twitter.Tweets.CreateThread,
      Lux.Prisms.Twitter.Tweets.LikeTweet,
      Lux.Prisms.Twitter.Tweets.Retweet,
      Lux.Prisms.Twitter.Users.FollowUser
    ]
end
```

## Supported Search Operators

| Operator | Example | Description |
|----------|---------|-------------|
| `from:` | `from:elikirf` | Tweets by user |
| `to:` | `to:elikirf` | Replies to user |
| `-is:retweet` | | Exclude retweets |
| `is:reply` | | Only replies |
| `has:media` | | With media |
| `has:links` | | With links |
| `lang:` | `lang:en` | By language |
| `#` | `#elixir` | Hashtag |
| `"exact"` | `"elixir lang"` | Exact phrase |
