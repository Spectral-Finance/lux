import os
import tweepy
from dotenv import load_dotenv

load_dotenv()

def get_twitter_api():
    auth = tweepy.OAuthHandler(
        os.getenv('TWITTER_API_KEY'),
        os.getenv('TWITTER_API_SECRET')
    )
    auth.set_access_token(
        os.getenv('TWITTER_ACCESS_TOKEN'),
        os.getenv('TWITTER_ACCESS_TOKEN_SECRET')
    )
    return tweepy.API(auth)

def search_tweets(keyword, limit=10):
    try:
        api = get_twitter_api()
        tweets = api.search_tweets(q=keyword, lang="en", count=limit)
        return [
            {
                'text': tweet.text,
                'created_at': tweet.created_at,
                'user': tweet.user.screen_name
            }
            for tweet in tweets
        ]
    except Exception as e:
        print(f"Error searching tweets: {str(e)}")
        return []
