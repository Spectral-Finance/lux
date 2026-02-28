# Twitter API Integration for Lux

Complete Twitter API v2 integration with OAuth 2.0, tweet management, and rate limiting.

## Features

- ✅ OAuth 2.0 authentication with PKCE
- ✅ Tweet creation, deletion, and threads
- ✅ Quote tweets and replies
- ✅ User profile management
- ✅ Rate limit handling with automatic retry
- ✅ Comprehensive error handling

## Installation

```bash
npm install lux-twitter-integration
```

## Quick Start

```javascript
const { TwitterClient } = require('lux-twitter-integration');

const client = new TwitterClient({
  clientId: process.env.TWITTER_CLIENT_ID,
  clientSecret: process.env.TWITTER_CLIENT_SECRET,
  redirectUri: 'http://localhost:3000/callback'
});

// Get authorization URL
const authUrl = client.auth.getAuthorizationUrl('random-state');

// After user authorization, exchange code for tokens
const tokens = await client.auth.exchangeCode(code);

// Create a tweet
const tweet = await client.createTweet('Hello from Lux!');

// Create a thread
const thread = await client.createThread([
  'First tweet',
  'Second tweet',
  'Third tweet'
]);
```

## API Reference

### Authentication

- `getAuthorizationUrl(state, scopes)` - Generate OAuth URL
- `exchangeCode(code)` - Exchange auth code for tokens
- `refreshToken()` - Refresh access token

### Tweets

- `createTweet(text, options)` - Create a tweet
- `createThread(tweets)` - Create a thread
- `deleteTweet(id)` - Delete a tweet
- `getTweet(id)` - Get tweet by ID

### Users

- `getUser(id)` - Get user by ID
- `getUserByUsername(username)` - Get user by username
- `getMe()` - Get authenticated user

## Testing

```bash
npm test
```

## License

MIT
