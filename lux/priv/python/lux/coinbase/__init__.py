"""
Coinbase Advanced Trade & Exchange Integration Package for Spectral Lux.
"""

from lux.coinbase.auth import CoinbaseAuth
from lux.coinbase.pipeline import CoinbasePipeline
from lux.coinbase.portfolio import AssetPosition, PortfolioTracker
from lux.coinbase.rate_limiter import CoinbaseRateLimiter, TokenBucket
from lux.coinbase.rest import (
    CoinbaseAPIError,
    CoinbaseAuthError,
    CoinbaseNotFoundError,
    CoinbaseRateLimitError,
    CoinbaseRestClient,
)
from lux.coinbase.types import (
    AccountBalance,
    Candle,
    CancelOrderResponse,
    ChannelType,
    Granularity,
    Order,
    OrderPlacementRequest,
    OrderSide,
    OrderStatus,
    OrderType,
    PortfolioSummary,
    Product,
    Ticker,
    TimeInForce,
)
from lux.coinbase.websocket import CoinbaseWebSocketManager

__all__ = [
    # Auth
    "CoinbaseAuth",
    # REST Client & Exceptions
    "CoinbaseRestClient",
    "CoinbaseAPIError",
    "CoinbaseAuthError",
    "CoinbaseRateLimitError",
    "CoinbaseNotFoundError",
    # Rate Limiting
    "CoinbaseRateLimiter",
    "TokenBucket",
    # WebSocket
    "CoinbaseWebSocketManager",
    # Portfolio & Risk
    "PortfolioTracker",
    "AssetPosition",
    # Pipeline
    "CoinbasePipeline",
    # Types & Enums
    "OrderSide",
    "OrderType",
    "OrderStatus",
    "TimeInForce",
    "Granularity",
    "ChannelType",
    "Product",
    "Order",
    "Candle",
    "Ticker",
    "AccountBalance",
    "PortfolioSummary",
    "OrderPlacementRequest",
    "CancelOrderResponse",
]
