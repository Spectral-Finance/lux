"""
Coinbase Advanced Trade & Exchange Types and Models.

This module provides strictly typed enumerations and Pydantic V2 data models
for the Coinbase Advanced Trade REST API and WebSocket integration suite.
"""

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional, Union
from pydantic import BaseModel, ConfigDict, Field, field_validator


class OrderSide(str, Enum):
    """Order side: BUY or SELL."""
    BUY = "BUY"
    SELL = "SELL"


class OrderType(str, Enum):
    """Order types supported by Coinbase Advanced Trade."""
    MARKET = "MARKET"
    LIMIT = "LIMIT"
    STOP_LIMIT = "STOP_LIMIT"
    STOP = "STOP"


class OrderStatus(str, Enum):
    """Standardized order lifecycle statuses."""
    OPEN = "OPEN"
    FILLED = "FILLED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"
    FAILED = "FAILED"
    PENDING = "PENDING"


class TimeInForce(str, Enum):
    """Time in force policies for order execution."""
    GTC = "GOOD_UNTIL_CANCELLED"
    IOC = "IMMEDIATE_OR_CANCEL"
    FOK = "FILL_OR_KILL"
    GTD = "GOOD_UNTIL_DATE_TIME"

    @classmethod
    def from_str(cls, value: str) -> "TimeInForce":
        val_upper = str(value).upper()
        if val_upper in ("GTC", "GOOD_UNTIL_CANCELLED"):
            return cls.GTC
        if val_upper in ("IOC", "IMMEDIATE_OR_CANCEL"):
            return cls.IOC
        if val_upper in ("FOK", "FILL_OR_KILL"):
            return cls.FOK
        if val_upper in ("GTD", "GOOD_UNTIL_DATE_TIME"):
            return cls.GTD
        return cls[val_upper] if val_upper in cls.__members__ else cls.GTC


class Granularity(str, Enum):
    """Candle interval granularities."""
    ONE_MINUTE = "ONE_MINUTE"
    FIVE_MINUTE = "FIVE_MINUTE"
    FIFTEEN_MINUTE = "FIFTEEN_MINUTE"
    ONE_HOUR = "ONE_HOUR"
    SIX_HOUR = "SIX_HOUR"
    ONE_DAY = "ONE_DAY"

    @property
    def seconds(self) -> int:
        mapping = {
            Granularity.ONE_MINUTE: 60,
            Granularity.FIVE_MINUTE: 300,
            Granularity.FIFTEEN_MINUTE: 900,
            Granularity.ONE_HOUR: 3600,
            Granularity.SIX_HOUR: 21600,
            Granularity.ONE_DAY: 86400,
        }
        return mapping[self]

    @classmethod
    def from_seconds(cls, seconds: int) -> "Granularity":
        mapping = {
            60: cls.ONE_MINUTE,
            300: cls.FIVE_MINUTE,
            900: cls.FIFTEEN_MINUTE,
            3600: cls.ONE_HOUR,
            21600: cls.SIX_HOUR,
            86400: cls.ONE_DAY,
        }
        if seconds not in mapping:
            raise ValueError(f"Unsupported granularity in seconds: {seconds}")
        return mapping[seconds]


class ChannelType(str, Enum):
    """Coinbase Advanced Trade WebSocket channel types."""
    TICKER = "ticker"
    HEARTBEATS = "heartbeats"
    CANDLES = "candles"
    STATUS = "status"
    USER = "user"
    LEVEL2 = "level2"


# ============================================================================
# Pydantic Models
# ============================================================================

class CoinbaseBaseModel(BaseModel):
    """Base Pydantic model with lenient string coercion and json serialization."""
    model_config = ConfigDict(
        populate_by_name=True,
        use_enum_values=True,
        arbitrary_types_allowed=True,
        extra="allow",
    )


class Product(CoinbaseBaseModel):
    """Coinbase Tradable Product Representation."""
    id: str = Field(..., alias="product_id")
    base_currency: str = Field(..., alias="base_currency_id")
    quote_currency: str = Field(..., alias="quote_currency_id")
    quote_increment: float = 0.01
    base_increment: float = 0.00000001
    status: str = "online"
    display_name: Optional[str] = None
    min_market_funds: Optional[float] = None
    max_market_funds: Optional[float] = None
    post_only: bool = False
    limit_only: bool = False
    cancel_only: bool = False
    status_message: Optional[str] = None

    @field_validator("id", mode="before")
    @classmethod
    def extract_id(cls, v: Any) -> Any:
        return str(v) if v is not None else ""

    @field_validator("base_currency", "quote_currency", mode="before")
    @classmethod
    def extract_str(cls, v: Any) -> str:
        return str(v) if v is not None else ""

    @field_validator("quote_increment", "base_increment", "min_market_funds", "max_market_funds", mode="before")
    @classmethod
    def parse_float(cls, v: Any) -> Optional[float]:
        if v is None:
            return None
        try:
            return float(v)
        except (ValueError, TypeError):
            return 0.0


class Candle(CoinbaseBaseModel):
    """Candlestick (OHLCV) Bar."""
    start: Union[str, int]
    low: float
    high: float
    open: float
    close: float
    volume: float

    @field_validator("low", "high", "open", "close", "volume", mode="before")
    @classmethod
    def parse_candle_float(cls, v: Any) -> float:
        try:
            return float(v)
        except (ValueError, TypeError):
            return 0.0


class Ticker(CoinbaseBaseModel):
    """Real-time 24h Ticker & Best Bid/Ask."""
    product_id: str
    price: float
    volume_24h: float = 0.0
    high_24h: float = 0.0
    low_24h: float = 0.0
    best_bid: float = 0.0
    best_ask: float = 0.0
    timestamp: Optional[str] = None

    @field_validator("price", "volume_24h", "high_24h", "low_24h", "best_bid", "best_ask", mode="before")
    @classmethod
    def parse_ticker_float(cls, v: Any) -> float:
        try:
            return float(v)
        except (ValueError, TypeError):
            return 0.0


class AccountBalance(CoinbaseBaseModel):
    """Single currency balance account."""
    currency: str
    available: float = 0.0
    hold: float = 0.0
    balance: float = 0.0
    account_uuid: Optional[str] = None

    @field_validator("available", "hold", "balance", mode="before")
    @classmethod
    def parse_balance_float(cls, v: Any) -> float:
        try:
            return float(v)
        except (ValueError, TypeError):
            return 0.0


class PortfolioSummary(CoinbaseBaseModel):
    """Aggregated portfolio summary."""
    total_balance_usd: float = 0.0
    accounts: List[AccountBalance] = Field(default_factory=list)
    unrealized_pnl: float = 0.0
    realized_pnl_24h: float = 0.0
    allocations: Dict[str, float] = Field(default_factory=dict)


class Order(CoinbaseBaseModel):
    """Advanced Trade Order representation."""
    order_id: str
    client_order_id: str = ""
    product_id: str
    side: OrderSide
    order_type: OrderType
    price: Optional[float] = None
    size: Optional[float] = None
    status: OrderStatus = OrderStatus.OPEN
    filled_size: float = 0.0
    filled_value: float = 0.0
    fee: float = 0.0
    created_at: Optional[str] = None
    time_in_force: Optional[Union[TimeInForce, str]] = None
    stop_price: Optional[float] = None
    average_filled_price: Optional[float] = None

    @field_validator("price", "size", "filled_size", "filled_value", "fee", "stop_price", "average_filled_price", mode="before")
    @classmethod
    def parse_order_floats(cls, v: Any) -> Optional[float]:
        if v is None:
            return None
        try:
            return float(v)
        except (ValueError, TypeError):
            return 0.0


class OrderPlacementRequest(CoinbaseBaseModel):
    """Parameters required to place an order on Coinbase Advanced Trade."""
    product_id: str
    side: OrderSide
    order_type: OrderType
    size: Optional[float] = None
    price: Optional[float] = None
    client_order_id: Optional[str] = None
    time_in_force: Optional[Union[TimeInForce, str]] = TimeInForce.GTC
    stop_price: Optional[float] = None
    quote_size: Optional[float] = None
    post_only: bool = False

    def to_coinbase_payload(self) -> Dict[str, Any]:
        """Convert request into Coinbase Advanced Trade order payload structure."""
        order_config: Dict[str, Any] = {}
        side_val = str(self.side.value if isinstance(self.side, OrderSide) else self.side).upper()
        type_val = str(self.order_type.value if isinstance(self.order_type, OrderType) else self.order_type).upper()

        if type_val in (OrderType.MARKET.value, "MARKET"):
            market_cfg: Dict[str, Any] = {}
            if side_val in (OrderSide.BUY.value, "BUY"):
                if self.quote_size is not None:
                    market_cfg["quote_size"] = str(self.quote_size)
                elif self.size is not None and self.price is not None:
                    market_cfg["quote_size"] = str(round(self.size * self.price, 2))
                elif self.size is not None:
                    market_cfg["base_size"] = str(self.size)
            else:
                if self.size is not None:
                    market_cfg["base_size"] = str(self.size)
            order_config["market_market_ioc"] = market_cfg

        elif type_val in (OrderType.LIMIT.value, "LIMIT"):
            tif_val = "GOOD_UNTIL_CANCELLED"
            if self.time_in_force:
                if isinstance(self.time_in_force, TimeInForce):
                    tif_val = self.time_in_force.value
                else:
                    tif_val = TimeInForce.from_str(str(self.time_in_force)).value

            limit_cfg = {
                "base_size": str(self.size or 0.0),
                "limit_price": str(self.price or 0.0),
                "post_only": self.post_only,
            }
            if tif_val == "GOOD_UNTIL_CANCELLED":
                order_config["limit_limit_gtc"] = limit_cfg
            elif tif_val == "IMMEDIATE_OR_CANCEL":
                order_config["limit_limit_ioc"] = limit_cfg
            elif tif_val == "FILL_OR_KILL":
                order_config["limit_limit_fok"] = limit_cfg
            else:
                order_config["limit_limit_gtc"] = limit_cfg

        elif type_val in (OrderType.STOP_LIMIT.value, "STOP_LIMIT", "STOP"):
            stop_cfg = {
                "base_size": str(self.size or 0.0),
                "limit_price": str(self.price or 0.0),
                "stop_price": str(self.stop_price or 0.0),
                "stop_direction": "STOP_DIRECTION_STOP_UP" if side_val == "BUY" else "STOP_DIRECTION_STOP_DOWN",
            }
            order_config["stop_limit_stop_limit_gtc"] = stop_cfg

        payload: Dict[str, Any] = {
            "product_id": self.product_id,
            "side": side_val,
            "order_configuration": order_config,
        }
        if self.client_order_id:
            payload["client_order_id"] = self.client_order_id

        return payload


class CancelOrderResponse(CoinbaseBaseModel):
    """Response returned upon cancelling an order."""
    success: bool
    order_id: Optional[str] = None
    failure_reason: Optional[str] = None
