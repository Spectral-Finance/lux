"""
NFT Data Types, Schemas, and Exceptions for Lux Framework.
"""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Any, Dict, List, Optional, Union
import datetime
import time


class Marketplace(str, Enum):
    OPENSEA = "opensea"
    BLUR = "blur"
    LOOKSRARE = "looksrare"
    UNKNOWN = "unknown"

    @classmethod
    def from_str(cls, val: str) -> "Marketplace":
        clean = (val or "").strip().lower()
        for m in cls:
            if m.value == clean or m.name.lower() == clean:
                return m
        return cls.UNKNOWN


class EventType(str, Enum):
    SALE = "sale"
    LISTING = "listing"
    OFFER = "offer"
    CANCEL = "cancel"
    TRANSFER = "transfer"
    UNKNOWN = "unknown"

    @classmethod
    def from_str(cls, val: str) -> "EventType":
        clean = (val or "").strip().lower()
        for e in cls:
            if e.value == clean or e.name.lower() == clean:
                return e
        return cls.UNKNOWN


class RarityTier(str, Enum):
    LEGENDARY = "Legendary"  # Top 1%
    EPIC = "Epic"            # Top 5%
    RARE = "Rare"            # Top 15%
    UNCOMMON = "Uncommon"    # Top 35%
    COMMON = "Common"        # Remaining 65%

    @classmethod
    def from_percentile(cls, percentile: float) -> "RarityTier":
        """Percentile where 0.0 is top (most rare) and 1.0 is least rare."""
        if percentile <= 0.01:
            return cls.LEGENDARY
        if percentile <= 0.05:
            return cls.EPIC
        if percentile <= 0.15:
            return cls.RARE
        if percentile <= 0.35:
            return cls.UNCOMMON
        return cls.COMMON


class TrendDirection(str, Enum):
    BULLISH = "BULLISH"
    BEARISH = "BEARISH"
    NEUTRAL = "NEUTRAL"
    BREAKOUT = "BREAKOUT"
    DUMPING = "DUMPING"


# --- Exceptions ---

class NFTMarketplaceError(Exception):
    """Base exception for all NFT marketplace operations."""
    def __init__(self, message: str, marketplace: Optional[str] = None, details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.message = message
        self.marketplace = marketplace
        self.details = details or {}


class RateLimitExceededError(NFTMarketplaceError):
    """Raised when marketplace rate limit is reached."""
    def __init__(self, message: str, retry_after: float = 1.0, marketplace: Optional[str] = None):
        super().__init__(message, marketplace=marketplace, details={"retry_after": retry_after})
        self.retry_after = retry_after


class MarketplaceAuthenticationError(NFTMarketplaceError):
    """Raised when API key or auth token is missing or invalid."""
    pass


class ResourceNotFoundError(NFTMarketplaceError):
    """Raised when collection or token is not found."""
    pass


class MarketplaceUnavailableError(NFTMarketplaceError):
    """Raised when a marketplace API is down, timed out, or unreachable."""
    pass


class InvalidResponseError(NFTMarketplaceError):
    """Raised when API returns malformed or unexpected data."""
    pass


class ValidationError(NFTMarketplaceError):
    """Raised when input parameters fail validation."""
    pass


# --- Data Models ---

@dataclass
class FeeBreakdown:
    marketplace_fee_percent: float = 0.0
    creator_fee_percent: float = 0.0
    total_fee_percent: float = 0.0
    marketplace_fee_eth: float = 0.0
    creator_fee_eth: float = 0.0

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class SaleEvent:
    event_id: str
    marketplace: Marketplace
    collection_address: str
    token_id: str
    price_raw: str
    price_eth: float
    price_usd: float
    payment_token: str
    buyer_address: str
    seller_address: str
    transaction_hash: str
    block_number: int
    timestamp: float
    event_type: EventType = EventType.SALE
    fee_breakdown: FeeBreakdown = field(default_factory=FeeBreakdown)
    token_name: Optional[str] = None
    image_url: Optional[str] = None
    raw_event: Optional[Dict[str, Any]] = None

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["marketplace"] = self.marketplace.value
        d["event_type"] = self.event_type.value
        return d

    @property
    def iso_timestamp(self) -> str:
        return datetime.datetime.fromtimestamp(self.timestamp, tz=datetime.timezone.utc).isoformat()


@dataclass
class FloorPriceQuote:
    marketplace: Marketplace
    collection_address: str
    floor_price_eth: float
    floor_price_usd: float
    currency: str
    token_id: Optional[str] = None
    listing_id: Optional[str] = None
    listing_url: Optional[str] = None
    maker_address: Optional[str] = None
    timestamp: float = field(default_factory=time.time)
    is_valid: bool = True

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["marketplace"] = self.marketplace.value
        return d


@dataclass
class AggregatedFloorPrice:
    collection_address: str
    best_floor_price_eth: float
    best_floor_price_usd: float
    best_marketplace: Marketplace
    quotes: Dict[str, FloorPriceQuote]
    spread_eth: float
    spread_percent: float
    timestamp: float = field(default_factory=time.time)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "collection_address": self.collection_address,
            "best_floor_price_eth": self.best_floor_price_eth,
            "best_floor_price_usd": self.best_floor_price_usd,
            "best_marketplace": self.best_marketplace.value,
            "spread_eth": round(self.spread_eth, 6),
            "spread_percent": round(self.spread_percent, 4),
            "quotes": {k: v.to_dict() for k, v in self.quotes.items()},
            "timestamp": self.timestamp,
        }


@dataclass
class CollectionStats:
    collection_address: str
    name: str
    symbol: Optional[str] = None
    total_supply: int = 0
    num_owners: int = 0
    floor_price_eth: float = 0.0
    floor_price_usd: float = 0.0
    volume_1h_eth: float = 0.0
    volume_24h_eth: float = 0.0
    volume_7d_eth: float = 0.0
    volume_30d_eth: float = 0.0
    volume_total_eth: float = 0.0
    sales_1h: int = 0
    sales_24h: int = 0
    sales_7d: int = 0
    sales_30d: int = 0
    sales_total: int = 0
    average_price_24h_eth: float = 0.0
    market_cap_eth: float = 0.0
    timestamp: float = field(default_factory=time.time)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class MovingAverages:
    sma_7: Optional[float] = None
    sma_24: Optional[float] = None
    sma_30: Optional[float] = None
    ema_7: Optional[float] = None
    ema_24: Optional[float] = None

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class PriceTrendAnalysis:
    collection_address: str
    current_floor_eth: float
    floor_24h_ago_eth: float
    price_change_24h_eth: float
    price_change_24h_percent: float
    volume_24h_eth: float
    volume_24h_ago_eth: float
    volume_change_24h_percent: float
    vwap_24h_eth: float
    volatility_24h: float
    moving_averages: MovingAverages
    trend_direction: TrendDirection
    liquidity_index: float
    support_level_eth: float
    resistance_level_eth: float
    outliers_filtered_count: int = 0
    analyzed_sales_count: int = 0
    timestamp: float = field(default_factory=time.time)

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["trend_direction"] = self.trend_direction.value
        d["moving_averages"] = self.moving_averages.to_dict()
        return d


@dataclass
class TraitAttribute:
    trait_type: str
    value: Union[str, int, float, bool]
    count: int = 0
    frequency: float = 0.0
    rarity_score: float = 0.0
    entropy_score: float = 0.0

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class TokenMetadata:
    token_id: str
    collection_address: str
    name: Optional[str] = None
    image_url: Optional[str] = None
    attributes: List[TraitAttribute] = field(default_factory=list)
    raw_metadata: Optional[Dict[str, Any]] = None

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["attributes"] = [a.to_dict() for a in self.attributes]
        return d


@dataclass
class TraitScoreDetail:
    trait_type: str
    value: Union[str, int, float, bool]
    count: int
    frequency: float
    rarity_score: float
    entropy_score: float
    is_missing_trait: bool = False
    is_trait_count: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class TokenRarityScore:
    token_id: str
    collection_address: str
    rank: int
    total_tokens: int
    percentile: float
    tier: RarityTier
    rarity_score: float
    entropy_score: float
    statistical_rarity: float
    harmonic_score: float
    trait_count: int
    rarest_trait: Optional[TraitScoreDetail] = None
    trait_details: List[TraitScoreDetail] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["tier"] = self.tier.value
        d["rarest_trait"] = self.rarest_trait.to_dict() if self.rarest_trait else None
        d["trait_details"] = [td.to_dict() for td in self.trait_details]
        return d


@dataclass
class CollectionRarityReport:
    collection_address: str
    total_supply: int
    total_traits_count: int
    trait_distribution: Dict[str, Dict[str, int]]
    token_scores: List[TokenRarityScore]
    trait_entropy: Dict[str, float]
    ranked_token_ids: List[str]
    generated_at: float = field(default_factory=time.time)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "collection_address": self.collection_address,
            "total_supply": self.total_supply,
            "total_traits_count": self.total_traits_count,
            "trait_distribution": self.trait_distribution,
            "token_scores": [ts.to_dict() for ts in self.token_scores],
            "trait_entropy": self.trait_entropy,
            "ranked_token_ids": self.ranked_token_ids,
            "generated_at": self.generated_at,
        }
