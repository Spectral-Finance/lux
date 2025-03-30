#!/usr/bin/env python3
"""
Twitter OAuth 2.0 Refresh Token Generator

This script helps you generate Twitter API OAuth 2.0 tokens, including a refresh token
that can be used in your Lux configuration.

Usage:
1. Register an app at https://developer.twitter.com/en/portal/dashboard
2. Get the CLIENT_ID and CLIENT_SECRET variables below
3. Set the REDIRECT_URI variable below to http://localhost:8000/callback
4. Run this script with your credentials:
   python twitter_oauth_generator.py --client-id YOUR_CLIENT_ID --client-secret YOUR_CLIENT_SECRET
5. Open the authorization URL in your browser
6. After authorizing, you'll be redirected and receive your tokens

Requirements:
- Flask
- Requests

Installation:
pip install flask requests
"""

import os
import secrets
import webbrowser
import argparse
from urllib.parse import urlencode
from flask import Flask, request, jsonify

# Set up command-line argument parsing
parser = argparse.ArgumentParser(description='Generate Twitter OAuth 2.0 tokens')
parser.add_argument('--client-id', required=True, help='Your Twitter API Client ID')
parser.add_argument('--client-secret', required=True, help='Your Twitter API Client Secret')
parser.add_argument('--port', type=int, default=8000, help='Port to run the local server on (default: 8000)')
parser.add_argument('--redirect-uri', default=None, help='Custom redirect URI (default: http://localhost:<port>/callback)')
args = parser.parse_args()

# Configuration from command-line arguments
CLIENT_ID = args.client_id
CLIENT_SECRET = args.client_secret
PORT = args.port
REDIRECT_URI = args.redirect_uri or f"http://localhost:{PORT}/callback"

# Generate a code verifier (for PKCE)
CODE_VERIFIER = secrets.token_urlsafe(64)[:128]  

app = Flask(__name__)

def generate_auth_url():
    """Generate the Twitter OAuth authorization URL."""
    params = {
        "response_type": "code",
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "scope": "tweet.read tweet.write users.read offline.access",
        "state": secrets.token_urlsafe(16),
        "code_challenge": CODE_VERIFIER,  # For simplicity, using plain challenge method
        "code_challenge_method": "plain"
    }
    
    auth_url = f"https://twitter.com/i/oauth2/authorize?{urlencode(params)}"
    return auth_url

@app.route("/")
def index():
    """Display instructions and the authorization link."""
    auth_url = generate_auth_url()
    return f"""
    <html>
        <head>
            <title>Twitter OAuth Token Generator</title>
            <style>
                body {{ font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }}
                pre {{ background-color: #f5f5f5; padding: 10px; border-radius: 5px; overflow-x: auto; }}
                .button {{ background-color: #1DA1F2; color: white; padding: 10px 15px; text-decoration: none; 
                         border-radius: 5px; display: inline-block; margin-top: 10px; }}
            </style>
        </head>
        <body>
            <h1>Twitter OAuth Token Generator</h1>
            <p>Click the button below to authorize this application with Twitter:</p>
            <a href="{auth_url}" class="button" target="_blank">Authorize with Twitter</a>
            
            <h3>How it works:</h3>
            <ol>
                <li>Click the button to open the Twitter authorization page</li>
                <li>Log in to Twitter and authorize the application</li>
                <li>You'll be redirected back to this application</li>
                <li>Your access token and refresh token will be displayed</li>
                <li>Copy the refresh token to your Lux configuration</li>
            </ol>
        </body>
    </html>
    """

@app.route("/callback")
def callback():
    """Handle the OAuth callback and exchange the code for tokens."""
    code = request.args.get("code")
    error = request.args.get("error")
    
    if error:
        return jsonify({"error": error})
    
    if not code:
        return jsonify({"error": "No authorization code received"})
    
    # Exchange the authorization code for tokens
    import requests
    
    token_resp = requests.post(
        "https://api.twitter.com/2/oauth2/token",
        auth=(CLIENT_ID, CLIENT_SECRET),
        data={
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": REDIRECT_URI,
            "code_verifier": CODE_VERIFIER,
        },
    )
    
    if token_resp.status_code != 200:
        return f"""
        <html>
            <head>
                <title>Error</title>
                <style>
                    body {{ font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }}
                    .error {{ color: red; }}
                </style>
            </head>
            <body>
                <h1 class="error">Error Getting Tokens</h1>
                <p>Status Code: {token_resp.status_code}</p>
                <pre>{token_resp.text}</pre>
            </body>
        </html>
        """
    
    tokens = token_resp.json()
    access_token = tokens.get("access_token")
    refresh_token = tokens.get("refresh_token")
    
    return f"""
    <html>
        <head>
            <title>Twitter OAuth Tokens</title>
            <style>
                body {{ font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }}
                .token-box {{ background-color: #f5f5f5; padding: 10px; border-radius: 5px; 
                            margin: 10px 0; word-break: break-all; }}
                .success {{ color: green; }}
            </style>
        </head>
        <body>
            <h1 class="success">Authorization Successful!</h1>
            
            <h2>Access Token:</h2>
            <div class="token-box">{access_token}</div>
            
            <h2>Refresh Token:</h2>
            <div class="token-box">{refresh_token}</div>
            
            <h3>Next Steps:</h3>
            <ol>
                <li>Copy the refresh token above</li>
                <li>Add it to your environment as <code>TWITTER_OAUTH_REFRESH_TOKEN</code></li>
                <li>The token will be available in Lux via <code>Lux.Config.twitter_oauth_refresh_token()</code></li>
            </ol>
            
            <p><strong>Note:</strong> This page will not be available after you close the server. 
            Make sure to save your tokens now!</p>
        </body>
    </html>
    """

if __name__ == "__main__":
    auth_url = generate_auth_url()
    print("\n=== Twitter OAuth Token Generator ===\n")
    print(f"Using Client ID: {CLIENT_ID}")
    print(f"Redirect URI: {REDIRECT_URI}")
    print(f"\nOpening browser to: {auth_url}")
    print("\nIf the browser doesn't open automatically, copy and paste the URL above into your browser.")
    print(f"\nServer running on http://localhost:{PORT}")
    
    # Try to open the browser automatically
    webbrowser.open(auth_url)
    
    # Run the Flask server
    app.run(host="localhost", port=PORT) 