# Twitter API v2 Integration for Lux

Complete Twitter API v2 integration using Lux Lens system.

## Features
- OAuth 2.0 Bearer Token authentication
- Tweet creation, deletion, retrieval
- Quote tweets and replies
- Media upload (images, videos, GIFs)
- User profile retrieval
- Rate limit handling

## Lenses
1. CreateTweet - Post tweets with media/replies
2. DeleteTweet - Delete tweets by ID
3. GetTweet - Retrieve tweet details
4. UploadMedia - Upload media files
5. GetUser - Get user profiles
6. GetUserTweets - Get user timeline
7. QuoteTweet - Quote existing tweets

## Configuration
```elixir
config :lux, :api_keys, twitter: System.get_env("TWITTER_BEARER_TOKEN")
```

See individual lens files for detailed examples.
