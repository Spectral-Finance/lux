"""
Coinbase Advanced Trade Unified Pipeline Orchestrator.

Combines REST API, WebSocket streams, Rate Limiter, and Portfolio Risk Tracker
into a high-level operational pipeline for trading bots, agents, and Elixir lenses.
"""

from datetime import datetime, timezone
import logging
from typing import Any, Callable, Dict, List, Optional, Union

from lux.coinbase.auth import CoinbaseAuth
from lux.coinbase.portfolio import PortfolioTracker
from lux.coinbase.rate_limiter import CoinbaseRateLimiter
from lux.coinbase.rest import CoinbaseRestClient
from lux.coinbase.types import (
    AccountBalance,
    Candle,
    ChannelType,
    Granularity,
    Order,
    OrderPlacementRequest,
    OrderStatus,
    OrderType,
    PortfolioSummary,
    Product,
    Ticker,
)
from lux.coinbase.websocket import CoinbaseWebSocketManager

logger = logging.getLogger(__name__)


class CoinbasePipeline:
    """
    Unified Orchestrator for Coinbase Advanced Trade.
    """

    def __init__(
        self,
        auth: Optional[CoinbaseAuth] = None,
        base_url: Optional[str] = None,
        ws_url: Optional[str] = None,
        max_concentration_pct: float = 40.0,
        max_position_usd: float = 100_000.0,
    ):
        self.auth = auth or CoinbaseAuth.from_env()
        self.rate_limiter = CoinbaseRateLimiter()
        
        self.rest = CoinbaseRestClient(
            auth=self.auth,
            base_url=base_url,
            rate_limiter=self.rate_limiter,
        )
        
        self.ws = CoinbaseWebSocketManager(
            auth=self.auth,
            ws_url=ws_url,
        )
        
        self.portfolio = PortfolioTracker(
            max_concentration_pct=max_concentration_pct,
            max_position_usd=max_position_usd,
        )

        self._active_stream_products: List[str] = []

    # ========================================================================
    # Portfolio & Balances Sync
    # ========================================================================

    def sync_portfolio(self) -> PortfolioSummary:
        """
        Fetch fresh account balances and mark-to-market prices from REST API,
        updating the internal PortfolioTracker state.
        """
        accounts = self.rest.get_accounts()
        for acc in accounts:
            self.portfolio.update_balance(
                currency=acc.currency,
                available=acc.available,
                hold=acc.hold,
            )

        # Update current spot prices for held assets
        held_currencies = [acc.currency for acc in accounts if (acc.available + acc.hold) > 0 and acc.currency not in ("USD", "USDC", "USDT")]
        if held_currencies:
            product_ids = [f"{curr}-USD" for curr in held_currencies]
            try:
                tickers = self.rest.get_best_bid_ask(product_ids=product_ids)
                for t in tickers:
                    self.portfolio.update_price(t.product_id, t.price)
            except Exception as e:
                logger.warning(f"Could not fetch mark-to-market prices during portfolio sync: {e}")

        return self.portfolio.get_summary()

    # ========================================================================
    # Market Data & Streaming
    # ========================================================================

    def start_streaming(
        self,
        product_ids: List[str],
        on_ticker: Optional[Callable[[Dict[str, Any]], None]] = None,
        on_order_update: Optional[Callable[[Dict[str, Any]], None]] = None,
    ) -> bool:
        """
        Start WebSocket feed and subscribe to ticker and user channels.
        """
        self._active_stream_products = list(set(self._active_stream_products + product_ids))
        
        # Internal ticker handler to keep portfolio prices fresh
        def _internal_ticker_listener(msg: Dict[str, Any]) -> None:
            events = msg.get("events", [])
            for evt in events:
                tickers = evt.get("tickers", [])
                for t_data in tickers:
                    p_id = t_data.get("product_id")
                    price = float(t_data.get("price", 0.0))
                    if p_id and price > 0:
                        self.portfolio.update_price(p_id, price)
            if on_ticker:
                on_ticker(msg)

        self.ws.register_callback(ChannelType.TICKER, _internal_ticker_listener)

        if on_order_update:
            self.ws.register_callback(ChannelType.USER, on_order_update)

        started = self.ws.start()
        if started:
            self.ws.subscribe(ChannelType.TICKER, self._active_stream_products)
            self.ws.subscribe(ChannelType.HEARTBEATS, ["heartbeats"])
            if self.auth.is_authenticated:
                self.ws.subscribe(ChannelType.USER)

        return started

    def stop_streaming(self) -> None:
        """Stop real-time WebSocket feeds."""
        self.ws.stop()

    def analyze_market(
        self,
        product_id: str,
        granularity: Union[Granularity, str] = Granularity.ONE_HOUR,
        lookback_bars: int = 50,
    ) -> Dict[str, Any]:
        """
        Perform quick technical and market analysis for a given product.
        """
        candles = self.rest.get_candles(
            product_id=product_id,
            granularity=granularity,
        )
        if not candles:
            return {"product_id": product_id, "status": "no_data"}

        sorted_candles = sorted(candles, key=lambda c: str(c.start))[-lookback_bars:]
        closes = [c.close for c in sorted_candles]
        highs = [c.high for c in sorted_candles]
        lows = [c.low for c in sorted_candles]
        volumes = [c.volume for c in sorted_candles]

        current_price = closes[-1] if closes else 0.0
        period_high = max(highs) if highs else 0.0
        period_low = min(lows) if lows else 0.0
        total_vol = sum(volumes)

        # Simple moving averages
        sma_20 = sum(closes[-20:]) / min(len(closes), 20) if closes else 0.0
        price_change_pct = ((closes[-1] - closes[0]) / closes[0] * 100.0) if len(closes) > 1 and closes[0] > 0 else 0.0

        return {
            "product_id": product_id,
            "current_price": current_price,
            "period_high": period_high,
            "period_low": period_low,
            "total_volume": round(total_vol, 4),
            "sma_20": round(sma_20, 4),
            "price_change_pct": round(price_change_pct, 2),
            "candle_count": len(sorted_candles),
        }

    # ========================================================================
    # Safe Order Execution
    # ========================================================================

    def execute_order(
        self,
        request: Union[OrderPlacementRequest, Dict[str, Any]],
        skip_risk_check: bool = False,
    ) -> Dict[str, Any]:
        """
        Execute an order safely through pre-trade risk checks and REST submission.
        """
        if isinstance(request, dict):
            req_model = OrderPlacementRequest.model_validate(request)
        else:
            req_model = request

        # 1. Pre-trade risk assessment
        risk_evaluation = {"is_valid": True, "violations": []}
        if not skip_risk_check:
            risk_evaluation = self.portfolio.check_risk_limits(req_model)
            if not risk_evaluation["is_valid"]:
                return {
                    "status": "REJECTED_BY_RISK_LIMITS",
                    "reason": "; ".join(risk_evaluation["violations"]),
                    "risk_evaluation": risk_evaluation,
                    "order": None,
                }

        # 2. Submit order via REST
        try:
            created_order = self.rest.create_order(req_model)
            
            # 3. Optimistically track simulated fill if market order or price available
            if req_model.price and req_model.size:
                self.portfolio.record_fill(
                    product_id=req_model.product_id,
                    side=req_model.side,
                    size=req_model.size,
                    price=req_model.price,
                )

            return {
                "status": "SUBMITTED",
                "order_id": created_order.order_id,
                "order": created_order.model_dump(),
                "risk_evaluation": risk_evaluation,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
        except Exception as e:
            logger.error(f"Failed to execute order for {req_model.product_id}: {e}")
            return {
                "status": "FAILED",
                "reason": str(e),
                "order": None,
                "risk_evaluation": risk_evaluation,
            }

    def close(self) -> None:
        """Shutdown all active streams and resources."""
        self.stop_streaming()
