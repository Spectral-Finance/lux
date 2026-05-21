import os
from binance.client import Client

def setup(api_key: str, api_secret: str, testnet: bool = False, use_usdt_futures: bool = False) -> Client:
    """
    Setup and return a Binance Client instance.
    
    Args:
        api_key (str): Binance API Key
        api_secret (str): Binance API Secret
        testnet (bool): Whether to use the Binance Testnet
        use_usdt_futures (bool): Whether the client is intended for USDT-M Futures.
    
    Returns:
        Client: The initialized Binance client
    """
    # Initialize the client
    client = Client(api_key, api_secret, testnet=testnet)
    
    return client
