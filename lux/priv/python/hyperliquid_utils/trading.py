from hyperliquid.utils import constants
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

def place_order(exchange, symbol: str, is_buy: bool, sz: float, price: float, 
                order_type=constants.OrderType.LIMIT, reduce_only=False) -> Dict[str, Any]:
    """
    Place a perpetual trading order with risk checks.
    
    Args:
        exchange: Hyperliquid Exchange instance
        symbol: Trading symbol (e.g., "BTC")
        is_buy: True for buy, False for sell
        sz: Order size in base currency
        price: Limit price
        order_type: LIMIT or MARKET
        reduce_only: Reduce position only flag
        
    Returns:
        Order execution result with status metadata
    """
    try:
        # Validate order parameters
        if sz <= 0:
            raise ValueError("Order size must be positive")
        if price <= 0 and order_type == constants.OrderType.LIMIT:
            raise ValueError("Limit price must be positive")

        # Execute order
        order_result = exchange.order(symbol, is_buy, sz, price, order_type, reduce_only=reduce_only)
        
        return {
            "status": "success",
            "data": order_result,
            "metadata": {
                "symbol": symbol,
                "side": "buy" if is_buy else "sell",
                "size": sz,
                "price": price,
                "order_type": order_type.value
            }
        }
    except Exception as e:
        logger.error(f"Order failed: {str(e)}")
        return {
            "status": "error",
            "message": str(e),
            "error_type": "order_execution"
        }

def get_positions(info, address: str) -> Dict[str, Any]:
    """
    Retrieve current perpetual positions with PnL calculation.
    
    Args:
        info: Hyperliquid Info instance
        address: User wallet address
        
    Returns:
        Current positions with calculated PnL
    """
    try:
        user_state = info.user_state(address)
        positions = user_state["positions"]
        
        # Calculate unrealized PnL for each position
        for position in positions:
            entry_px = float(position["entryPx"])
            mark_px = float(position["markPx"])
            position["unrealized_pnl"] = (mark_px - entry_px) * float(position["position"]["szi"]) * (-1 if position["position"]["dir"] == "SHORT" else 1)
        
        return {
            "status": "success",
            "data": positions,
            "metadata": {
                "count": len(positions),
                "total_value": sum(float(p["position"]["szi"]) * float(p["markPx"]) for p in positions)
            }
        }
    except Exception as e:
        logger.error(f"Position retrieval failed: {str(e)}")
        return {
            "status": "error",
            "message": str(e),
            "error_type": "position_retrieval"
        }

def set_leverage(exchange, leverage: int) -> Dict[str, Any]:
    """
    Set leverage for perpetual trading with validation.
    
    Args:
        exchange: Hyperliquid Exchange instance
        leverage: Desired leverage (1-100)
        
    Returns:
        Leverage update result
    """
    try:
        # Validate leverage
        if not 1 <= leverage <= 100:
            raise ValueError("Leverage must be between 1-100")
            
        result = exchange.update_leverage(leverage)
        return {
            "status": "success",
            "data": result,
            "metadata": {"leverage": leverage}
        }
    except Exception as e:
        logger.error(f"Leverage update failed: {str(e)}")
        return {
            "status": "error",
            "message": str(e),
            "error_type": "leverage_update"
        }