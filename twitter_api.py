import tweepy
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

class TwitterAPI:
    def __init__(self, api_key, api_secret, access_token, access_token_secret):
        if not all([api_key, api_secret, access_token, access_token_secret]):
            raise ValueError("All Twitter API credentials are required")
        
        auth = tweepy.OAuthHandler(api_key, api_secret)
        auth.set_access_token(access_token, access_token_secret)
        self.api = tweepy.API(auth, wait_on_rate_limit=True)

    def search_tweets(self, query, count=10):
        try:
            tweets = self.api.search_tweets(q=query, count=count, tweet_mode='extended')
            return [{
                'id': tweet.id,
                'text': tweet.full_text,
                'user': {
                    'name': tweet.user.name,
                    'screen_name': tweet.user.screen_name,
                    'profile_image': tweet.user.profile_image_url_https
                },
                'created_at': tweet.created_at.strftime('%Y-%m-%d %H:%M:%S'),
                'retweet_count': tweet.retweet_count,
                'favorite_count': tweet.favorite_count
            } for tweet in tweets]
        except tweepy.RateLimitError:
            logger.error("Rate limit exceeded")
            raise Exception("Twitter API rate limit exceeded. Please try again later.")
        except tweepy.TweepyException as e:
            logger.error(f"Tweepy error: {str(e)}")
            raise Exception("Error accessing Twitter API")
