/**
 * Twitter API Client
 * Core API operations with rate limiting and error handling
 */

const axios = require('axios');
const { TwitterAuth } = require('./auth');

class TwitterClient {
  constructor(authConfig) {
    this.auth = new TwitterAuth(authConfig);
    this.baseUrl = 'https://api.twitter.com/2';
    this.uploadUrl = 'https://upload.twitter.com/1.1';
    
    // Rate limit tracking
    this.rateLimits = new Map();
    
    // Create axios instance with interceptors
    this.http = axios.create({
      baseURL: this.baseUrl,
      timeout: 30000
    });
    
    // Request interceptor - add auth header
    this.http.interceptors.request.use(async (config) => {
      const token = await this.auth.getAccessToken();
      config.headers.Authorization = `Bearer ${token}`;
      return config;
    });
    
    // Response interceptor - track rate limits
    this.http.interceptors.response.use(
      (response) => {
        this.trackRateLimit(response);
        return response;
      },
      async (error) => {
        if (error.response?.status === 429) {
          // Rate limited - wait and retry
          const resetTime = error.response.headers['x-rate-limit-reset'];
          const waitMs = resetTime ? (resetTime * 1000 - Date.now()) : 60000;
          console.log(`Rate limited. Waiting ${waitMs}ms...`);
          await this.sleep(waitMs);
          return this.http.request(error.config);
        }
        
        if (error.response?.status === 401) {
          // Token expired - refresh and retry
          await this.auth.refreshToken();
          return this.http.request(error.config);
        }
        
        return Promise.reject(error);
      }
    );
  }

  trackRateLimit(response) {
    const endpoint = response.config.url;
    this.rateLimits.set(endpoint, {
      limit: response.headers['x-rate-limit-limit'],
      remaining: response.headers['x-rate-limit-remaining'],
      reset: response.headers['x-rate-limit-reset']
    });
  }

  sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  // ==================== TWEET OPERATIONS ====================

  /**
   * Create a tweet
   */
  async createTweet(text, options = {}) {
    const payload = { text };
    
    if (options.reply) {
      payload.reply = { in_reply_to_tweet_id: options.reply };
    }
    
    if (options.quote) {
      payload.quote_tweet_id = options.quote;
    }
    
    if (options.media) {
      payload.media = { media_ids: options.media };
    }
    
    const response = await this.http.post('/tweets', payload);
    return response.data;
  }

  /**
   * Create a thread (multiple tweets)
   */
  async createThread(tweets) {
    const results = [];
    let previousId = null;
    
    for (const text of tweets) {
      const tweet = await this.createTweet(text, {
        reply: previousId
      });
      results.push(tweet);
      previousId = tweet.data.id;
    }
    
    return results;
  }

  /**
   * Delete a tweet
   */
  async deleteTweet(tweetId) {
    const response = await this.http.delete(`/tweets/${tweetId}`);
    return response.data;
  }

  /**
   * Get tweet by ID
   */
  async getTweet(tweetId, expansions = []) {
    const params = new URLSearchParams();
    if (expansions.length > 0) {
      params.append('expansions', expansions.join(','));
    }
    
    const response = await this.http.get(`/tweets/${tweetId}?${params}`);
    return response.data;
  }

  // ==================== USER OPERATIONS ====================

  /**
   * Get user by ID
   */
  async getUser(userId) {
    const response = await this.http.get(`/users/${userId}`);
    return response.data;
  }

  /**
   * Get user by username
   */
  async getUserByUsername(username) {
    const response = await this.http.get(`/users/by/username/${username}`);
    return response.data;
  }

  /**
   * Get authenticated user
   */
  async getMe() {
    const response = await this.http.get('/users/me');
    return response.data;
  }

  // ==================== MEDIA UPLOAD ====================

  /**
   * Upload media (simplified - INIT, APPEND, FINALIZE)
   */
  async uploadMedia(buffer, mimeType) {
    // This is a simplified version - full implementation requires chunked upload
    const token = await this.auth.getAccessToken();
    
    const formData = new FormData();
    formData.append('media', buffer);
    
    const response = await axios.post(
      `${this.uploadUrl}/media/upload.json`,
      formData,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'multipart/form-data'
        }
      }
    );
    
    return response.data.media_id_string;
  }

  // ==================== RATE LIMIT INFO ====================

  getRateLimitInfo(endpoint) {
    return this.rateLimits.get(endpoint);
  }
}

module.exports = { TwitterClient };
