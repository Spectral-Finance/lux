"""
Coinbase Advanced Trade Portfolio Tracker & Risk Management Engine.

Provides real-time portfolio balance aggregation, USD mark-to-market valuation,
asset allocation breakdowns, 24-hour PnL tracking, and position risk limit enforcement.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
import logging
from typing import Any, Dict, List, Optional, Union

from lux.coinbase.types import (
    AccountBalance,
    OrderPlacementRequest,
    OrderSide,
    PortfolioSummary,
)

logger = logging.getLogger(__name__)


@dataclass
class AssetPosition:
    """Detailed position state for an individual asset."""
    currency: str
    available: float = 0.0
    hold: float = 0.0
    cost_basis_usd: float = 0.0
    realized_pnl_24h: float = 0.0
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def total_balance(self) -> float:
        return self.available + self.hold


class PortfolioTracker:
    """
    Real-time Portfolio Tracker with Risk Limit Enforcement.
    """

    def __init__(
        self,
        max_concentration_pct: float = 40.0,
        max_position_usd: float = 100_000.0,
        max_leverage: float = 1.0,
        base_fiat: str = "USD",
    ):
        """
        Args:
            max_concentration_pct: Maximum percentage of total portfolio allowed in a single asset.
            max_position_usd: Maximum dollar value allowed for any individual position.
            max_leverage: Maximum portfolio leverage allowed.
            base_fiat: Quote fiat currency (default 'USD').
        """
        self.max_concentration_pct = max_concentration_pct
        self.max_position_usd = max_position_usd
        self.max_leverage = max_leverage
        self.base_fiat = base_fiat.upper()

        self._positions: Dict[str, AssetPosition] = {}
        self._prices: Dict[str, float] = {self.base_fiat: 1.0, "USDC": 1.0, "USDT": 1.0}
        self._initial_day_balance: Optional[float] = None

    # ========================================================================
    # State Updates
    # ========================================================================

    def update_balance(
        self,
        currency: str,
        available: float,
        hold: float = 0.0,
        cost_basis_usd: Optional[float] = None,
    ) -> None:
        """Update or insert account balance for a given asset currency."""
        curr = currency.upper()
        if curr not in self._positions:
            self._positions[curr] = AssetPosition(
                currency=curr,
                available=float(available),
                hold=float(hold),
                cost_basis_usd=float(cost_basis_usd or 0.0),
            )
        else:
            pos = self._positions[curr]
            pos.available = float(available)
            pos.hold = float(hold)
            if cost_basis_usd is not None:
                pos.cost_basis_usd = float(cost_basis_usd)
            pos.updated_at = datetime.now(timezone.utc)

    def update_price(self, product_id: str, price: float) -> None:
        """
        Update the current market price for an asset.
        `product_id` can be 'BTC-USD', 'ETH-USDC', or a raw currency like 'BTC'.
        """
        px = float(price)
        if "-" in product_id:
            base, quote = product_id.upper().split("-")
            quote_px = self._prices.get(quote, 1.0)
            self._prices[base] = px * quote_px
        else:
            self._prices[product_id.upper()] = px

    def record_fill(
        self,
        product_id: str,
        side: Union[OrderSide, str],
        size: float,
        price: float,
        fee: float = 0.0,
    ) -> None:
        """
        Record a trade execution fill and update position balances, cost basis, and realized PnL.
        """
        base_curr, quote_curr = product_id.upper().split("-")
        side_str = str(side.value if isinstance(side, OrderSide) else side).upper()
        trade_val_usd = float(size) * float(price)

        # Update base asset
        base_pos = self._positions.setdefault(base_curr, AssetPosition(currency=base_curr))
        quote_pos = self._positions.setdefault(quote_curr, AssetPosition(currency=quote_curr))

        if side_str == "BUY":
            # Increase base, decrease quote
            new_total = base_pos.total_balance + size
            if new_total > 0:
                base_pos.cost_basis_usd = ((base_pos.cost_basis_usd * base_pos.total_balance) + trade_val_usd) / new_total
            base_pos.available += size
            quote_pos.available = max(0.0, quote_pos.available - (trade_val_usd + fee))
        else:
            # SELL: Realize PnL
            cost_basis = base_pos.cost_basis_usd if base_pos.cost_basis_usd > 0 else price
            realized_pnl = (price - cost_basis) * size - fee
            base_pos.realized_pnl_24h += realized_pnl
            base_pos.available = max(0.0, base_pos.available - size)
            quote_pos.available += (trade_val_usd - fee)

    # ========================================================================
    # Valuations & Aggregations
    # ========================================================================

    def get_asset_valuation_usd(self, currency: str) -> float:
        """Get the current total USD value of a held asset."""
        curr = currency.upper()
        pos = self._positions.get(curr)
        if not pos:
            return 0.0
        price = self._prices.get(curr, 0.0)
        return pos.total_balance * price

    def get_total_balance_usd(self) -> float:
        """Calculate the total net asset value of all positions in USD."""
        total = 0.0
        for curr in self._positions:
            total += self.get_asset_valuation_usd(curr)
        return total

    def get_allocations(self) -> Dict[str, float]:
        """Calculate asset allocation percentage breakdown."""
        total_usd = self.get_total_balance_usd()
        if total_usd <= 0.0:
            return {curr: 0.0 for curr in self._positions}

        allocations: Dict[str, float] = {}
        for curr in self._positions:
            val = self.get_asset_valuation_usd(curr)
            allocations[curr] = round((val / total_usd) * 100.0, 2)
        return allocations

    def calculate_pnl_24h(self) -> Dict[str, float]:
        """
        Calculate realized, unrealized, and total 24h PnL across all assets in USD.
        """
        total_realized = sum(p.realized_pnl_24h for p in self._positions.values())
        total_unrealized = 0.0

        for curr, pos in self._positions.items():
            if curr in (self.base_fiat, "USDC", "USDT"):
                continue
            curr_px = self._prices.get(curr, 0.0)
            if pos.cost_basis_usd > 0 and pos.total_balance > 0:
                unrealized = (curr_px - pos.cost_basis_usd) * pos.total_balance
                total_unrealized += unrealized

        return {
            "realized_pnl_usd": round(total_realized, 2),
            "unrealized_pnl_usd": round(total_unrealized, 2),
            "total_pnl_usd": round(total_realized + total_unrealized, 2),
        }

    def get_summary(self) -> PortfolioSummary:
        """Export standardized PortfolioSummary model."""
        total_usd = self.get_total_balance_usd()
        pnl_data = self.calculate_pnl_24h()
        accounts: List[AccountBalance] = []

        for p in self._positions.values():
            accounts.append(
                AccountBalance(
                    currency=p.currency,
                    available=p.available,
                    hold=p.hold,
                    balance=p.total_balance,
                )
            )

        return PortfolioSummary(
            total_balance_usd=round(total_usd, 2),
            accounts=accounts,
            allocations=self.get_allocations(),
            unrealized_pnl=pnl_data["unrealized_pnl_usd"],
            realized_pnl_24h=pnl_data["realized_pnl_usd"],
        )

    # ========================================================================
    # Risk Management & Limits
    # ========================================================================

    def check_risk_limits(
        self,
        proposed_order: Optional[Union[OrderPlacementRequest, Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        """
        Evaluate portfolio risk limits before executing a trade.
        
        Checks:
        1. Single-asset concentration limit (`max_concentration_pct`).
        2. Maximum position size in USD (`max_position_usd`).
        3. Sufficient available balance for order.
        
        Returns:
            Dictionary with `is_valid` (bool), `violations` (list[str]), and metrics.
        """
        violations: List[str] = []
        total_portfolio_usd = self.get_total_balance_usd()

        if proposed_order is None:
            # Validate current portfolio state against limits
            allocations = self.get_allocations()
            for curr, pct in allocations.items():
                if curr not in (self.base_fiat, "USDC", "USDT") and pct > self.max_concentration_pct:
                    violations.append(
                        f"Asset {curr} concentration {pct:.1f}% exceeds limit {self.max_concentration_pct:.1f}%"
                    )
            return {
                "is_valid": len(violations) == 0,
                "violations": violations,
                "total_portfolio_usd": total_portfolio_usd,
            }

        # Validate proposed order simulation
        if isinstance(proposed_order, dict):
            order = OrderPlacementRequest.model_validate(proposed_order)
        else:
            order = proposed_order

        base_curr, quote_curr = order.product_id.upper().split("-")
        side_str = str(order.side.value if isinstance(order.side, OrderSide) else order.side).upper()
        
        # Estimate order USD value
        order_px = order.price or self._prices.get(base_curr, 0.0)
        order_size = order.size or (order.quote_size / order_px if order.quote_size and order_px > 0 else 0.0)
        order_val_usd = order_size * order_px

        # 1. Balance Availability Check
        if side_str == "BUY":
            quote_pos = self._positions.get(quote_curr)
            avail_quote = quote_pos.available if quote_pos else 0.0
            if avail_quote < order_val_usd:
                violations.append(
                    f"Insufficient {quote_curr} available balance ({avail_quote:.2f} < {order_val_usd:.2f})"
                )

            # Simulated post-order concentration
            curr_base_usd = self.get_asset_valuation_usd(base_curr)
            post_order_usd = curr_base_usd + order_val_usd
            post_pct = (post_order_usd / (total_portfolio_usd or 1.0)) * 100.0

            if post_pct > self.max_concentration_pct:
                violations.append(
                    f"Proposed BUY would push {base_curr} concentration to {post_pct:.1f}% (max {self.max_concentration_pct:.1f}%)"
                )

            if post_order_usd > self.max_position_usd:
                violations.append(
                    f"Proposed position size ${post_order_usd:.2f} exceeds max position limit ${self.max_position_usd:.2f}"
                )
        else:
            # SELL check
            base_pos = self._positions.get(base_curr)
            avail_base = base_pos.available if base_pos else 0.0
            if avail_base < order_size:
                violations.append(
                    f"Insufficient {base_curr} available balance ({avail_base:.4f} < {order_size:.4f})"
                )

        return {
            "is_valid": len(violations) == 0,
            "violations": violations,
            "order_value_usd": round(order_val_usd, 2),
            "total_portfolio_usd": round(total_portfolio_usd, 2),
        }
