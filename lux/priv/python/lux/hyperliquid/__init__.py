# Fix for Issue #82: Hyperliquid Integration and Perpetual Trading $900

"""
Hyperliquid Integration Module for Lux Framework

Provides perpetual trading capabilities including:
- Order placement and management
- Position tracking
- Risk management
- Liquidation monitoring
- Margin management
- PnL tracking
"""

from .client import HyperliquidClient
from .position_manager import PositionManager
from .risk_manager import RiskManager
from .order_executor import OrderExecutor
from .margin_manager import MarginManager
from .liquidation_monitor import LiquidationMonitor
from .pnl_tracker import PnLTracker

__all__ = [
    "HyperliquidClient",
    "PositionManager",
    "RiskManager",
    "OrderExecutor",
    "MarginManager",
    "LiquidationMonitor",
    "PnLTracker",
]

__version__ = "1.0.0"