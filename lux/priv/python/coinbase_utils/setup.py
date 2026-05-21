from coinbase.rest import RESTClient

def setup(api_key: str, api_secret: str) -> RESTClient:
    return RESTClient(api_key=api_key, api_secret=api_secret)
