import os
import logging
from flask import Flask, render_template, request, jsonify
from dotenv import load_dotenv
from twitter_api import TwitterAPI

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "default_secret_key")

# Initialize Twitter API client
twitter_api = TwitterAPI(
    api_key=os.environ.get("TWITTER_API_KEY"),
    api_secret=os.environ.get("TWITTER_API_SECRET"),
    access_token=os.environ.get("TWITTER_ACCESS_TOKEN"),
    access_token_secret=os.environ.get("TWITTER_ACCESS_TOKEN_SECRET")
)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/search')
def search():
    query = request.args.get('q', '')
    
    if not query:
        return jsonify({'error': 'Search query is required'}), 400
    
    try:
        tweets = twitter_api.search_tweets(query)
        return jsonify({'tweets': tweets})
    except Exception as e:
        logger.error(f"Error searching tweets: {str(e)}")
        return jsonify({'error': str(e)}), 500
