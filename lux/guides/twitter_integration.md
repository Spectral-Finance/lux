# Twitter (X) API Core Integration Guide

This guide details the architecture, design principles, and operational workflows for autonomous agent Twitter integration within Lux.

---

## 1. Architecture Overview

Lux provides a native, end-to-end integration with the Twitter (X) API v2 and media upload v1.1 systems. Designed specifically for autonomous agents, this module supports OAuth 2.0 with PKCE, tweet and thread orchestration, media asset uploads, rate limit defense, and high-level Prism integration.

```mermaid
flowchart TD
    Agent[Autonomous Agent / Prism] --> Facade[Lux.Integrations.Twitter]
    Facade --> Client[Twitter.Client\n(Req HTTP, Error translation, Header parsing)]
    Facade --> OAuth[Twitter.OAuth\n(RFC 7636 PKCE S256, Refresh, AES-256-GCM)]
    Facade --> Tweets[Twitter.Tweets\n(Create, Delete, Lookup, Thread chaining)]
    Facade --> Users[Twitter.Users\n(Me, By Username, By ID)]
    Facade --> Media[Twitter.Media\n(Simple & Chunked INIT/APPEND/FINALIZE)]
    Facade --> RateLimiter[Twitter.RateLimiter\n(Header tracking & Exponential backoff)]
    
    Agent --> Lenses[Lux.Lenses.Twitter\n(CreateTweet, DeleteTweet, GetTweet, GetUser)]
```

---

## 2. Modules & Capabilities

### 2.1 OAuth 2.0 PKCE Flow (`Lux.Integrations.Twitter.OAuth`)
Twitter API v2 requires OAuth 2.0 with PKCE (RFC 7636) for user context:
- **`generate_pkce_challenge/0`**: Generates a high-entropy 64-byte `code_verifier` and its base64url SHA-256 `code_challenge`.
- **`authorization_url/5`**: Builds standard Twitter authorization endpoints with requested scopes (`tweet.read`, `tweet.write`, `offline.access`, etc.).
- **`exchange_code/6`**: Exchanges one-time code for access and refresh tokens.
- **`refresh_token/4`**: Automates access token rotation before expiration.
- **`encrypt_token/2` & `decrypt_token/2`**: Secures tokens at rest using AES-256-GCM authenticated encryption with PBKDF2 salt derivation.

### 2.2 Tweet & Thread Management (`Lux.Integrations.Twitter.Tweets`)
- **`create_tweet/2`**: Publishes standalone tweets, tweets with up to 4 media attachments, quote tweets, and custom polls.
- **`create_thread/2`**: Takes a list of tweet strings or payload maps and automatically chains them by setting `reply: %{in_reply_to_tweet_id: previous_id}`.
- **`delete_tweet/2`**: Deletes tweets by ID.
- **`get_tweet/2`**: Retrieves tweet content, engagement metrics (`like_count`, `retweet_count`), author metadata, and expanded attachments.

### 2.3 User Profiles (`Lux.Integrations.Twitter.Users`)
- **`get_me/1`**: Fetches the authenticated agent's account details.
- **`get_user_by_username/2`**: Resolves Twitter handles (with or without `@`).
- **`get_user_by_id/2`**: Resolves numerical user IDs.

### 2.4 Media Upload Pipeline (`Lux.Integrations.Twitter.Media`)
- **Simple Upload (`upload_simple/3`)**: Base64 payload upload for images (JPG, PNG, WEBP) under 5MB.
- **Chunked Upload (`chunked_init/4`, `chunked_append/4`, `chunked_finalize/2`)**: 3-step chunked upload for videos (MP4) and large animated GIFs up to 512MB.

### 2.5 Dynamic Rate Limiting (`Lux.Integrations.Twitter.RateLimiter`)
- Parses `x-rate-limit-limit`, `x-rate-limit-remaining`, and `x-rate-limit-reset` headers from every response.
- Automatically throttles requests when remaining quota hits 0.
- Implements exponential backoff with random jitter upon HTTP 429 status codes.

---

## 3. Autonomous Agent Prism Integration

Agents invoke the infrastructure seamlessly using `Lux.Prisms.TwitterCorePrism`:

```elixir
# 1. Post a standalone tweet
{:ok, %{result: tweet}} =
  Lux.Prisms.TwitterCorePrism.run(%{
    action: "post_tweet",
    payload: %{
      text: "Autonomous operations launched on Lux! 🚀"
    }
  })

# 2. Publish an educational multi-tweet thread
{:ok, %{result: thread}} =
  Lux.Prisms.TwitterCorePrism.run(%{
    action: "post_thread",
    payload: %{
      tweets: [
        "1/3 Announcing our new multi-agent collaboration architecture.",
        "2/3 Lux allows autonomous agents to coordinate via prisms, lenses, and beams.",
        "3/3 Visit docs.spectral.finance to learn more."
      ]
    }
  })

# 3. Lookup target user metrics
{:ok, %{result: user}} =
  Lux.Prisms.TwitterCorePrism.run(%{
    action: "lookup_user",
    payload: %{username: "Spectral_Fi"}
  })
```

---

## 4. Lux Lens Usage

To query or publish directly in pipelines:

```elixir
alias Lux.Lenses.Twitter.Tweets.CreateTweet

{:ok, result} =
  CreateTweet.focus(%{
    "text" => "Direct lens execution from agent pipeline"
  })
```
