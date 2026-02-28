/**
 * Twitter OAuth 2.0 Authentication
 * Implements PKCE flow for secure token exchange
 */

const crypto = require('crypto');
const axios = require('axios');

class TwitterAuth {
  constructor({ clientId, clientSecret, redirectUri }) {
    this.clientId = clientId;
    this.clientSecret = clientSecret;
    this.redirectUri = redirectUri;
    this.baseUrl = 'https://api.twitter.com/2';
    
    // Token storage (in production, use secure storage)
    this.tokens = {
      accessToken: null,
      refreshToken: null,
      expiresAt: null
    };
  }

  /**
   * Generate PKCE parameters
   */
  generatePKCE() {
    const codeVerifier = crypto.randomBytes(32).toString('base64url');
    const codeChallenge = crypto
      .createHash('sha256')
      .update(codeVerifier)
      .digest('base64url');
    
    return {
      codeVerifier,
      codeChallenge,
      codeChallengeMethod: 'S256'
    };
  }

  /**
   * Get authorization URL
   */
  getAuthorizationUrl(state, scopes = ['tweet.read', 'tweet.write', 'users.read']) {
    const pkce = this.generatePKCE();
    
    // Store code verifier for later (in production, use session/cache)
    this.codeVerifier = pkce.codeVerifier;
    
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.clientId,
      redirect_uri: this.redirectUri,
      scope: scopes.join(' '),
      state: state,
      code_challenge: pkce.codeChallenge,
      code_challenge_method: pkce.codeChallengeMethod
    });
    
    return `https://twitter.com/i/oauth2/authorize?${params.toString()}`;
  }

  /**
   * Exchange authorization code for tokens
   */
  async exchangeCode(code) {
    try {
      const response = await axios.post(
        'https://api.twitter.com/2/oauth2/token',
        new URLSearchParams({
          grant_type: 'authorization_code',
          code: code,
          redirect_uri: this.redirectUri,
          code_verifier: this.codeVerifier,
          client_id: this.clientId
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Basic ${Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64')}`
          }
        }
      );
      
      this.tokens = {
        accessToken: response.data.access_token,
        refreshToken: response.data.refresh_token,
        expiresAt: Date.now() + (response.data.expires_in * 1000)
      };
      
      return this.tokens;
    } catch (error) {
      throw new Error(`Token exchange failed: ${error.response?.data?.error_description || error.message}`);
    }
  }

  /**
   * Refresh access token
   */
  async refreshToken() {
    if (!this.tokens.refreshToken) {
      throw new Error('No refresh token available');
    }
    
    try {
      const response = await axios.post(
        'https://api.twitter.com/2/oauth2/token',
        new URLSearchParams({
          grant_type: 'refresh_token',
          refresh_token: this.tokens.refreshToken,
          client_id: this.clientId
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Basic ${Buffer.from(`${this.clientId}:${this.clientSecret}`).toString('base64')}`
          }
        }
      );
      
      this.tokens = {
        accessToken: response.data.access_token,
        refreshToken: response.data.refresh_token || this.tokens.refreshToken,
        expiresAt: Date.now() + (response.data.expires_in * 1000)
      };
      
      return this.tokens;
    } catch (error) {
      throw new Error(`Token refresh failed: ${error.response?.data?.error_description || error.message}`);
    }
  }

  /**
   * Get valid access token (refresh if needed)
   */
  async getAccessToken() {
    if (!this.tokens.accessToken) {
      throw new Error('Not authenticated');
    }
    
    // Refresh if expiring in 5 minutes
    if (Date.now() >= this.tokens.expiresAt - 300000) {
      await this.refreshToken();
    }
    
    return this.tokens.accessToken;
  }
}

module.exports = { TwitterAuth };
