import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

def place_order(exchange, symbol: str, is_buy: bool, sz: float, price: float, 
                order_type="LIMIT", reduce_only=False) -> Dict[str, Any]:
    """
    Place a perpetual trading order with risk checks.
    
    Args:
        exchange: Hyperliquid Exchange instance
        symbol: Trading symbol (e.g., "BTC")
        is_buy: True for buy, False for sell
        sz: Order size in base currency
        price: Limit price
        order_type: Order type (LIMIT, MARKET, or dict like {"limit": {"tif": "Gtc"}})
        reduce_only: Reduce position only flag
        
    Returns:
        Order execution result with status metadata
    """
    try:
        # Validate order parameters
        if sz <= 0:
            raise ValueError("Order size must be positive")
        if price <= 0 and (order_type == "LIMIT" or (isinstance(order_type, dict) and "limit" in order_type)):
            raise ValueError("Limit price must be positive")

        # Normalize order_type for Hyperliquid SDK if string passed
        if order_type == "LIMIT":
            sdk_order_type = {"limit": {"tif": "Gtc"}}
        elif order_type == "MARKET":
            sdk_order_type = {"limit": {"tif": "Ioc"}}
        else:
            sdk_order_type = order_type

        # Execute order
        order_result = exchange.order(symbol, is_buy, sz, price, sdk_order_type, reduce_only=reduce_only)
        
        return {
            "status": "success",
            "data": order_result,
            "metadata": {
                "symbol": symbol,
                "side": "buy" if is_buy else "sell",
                "size": sz,
                "price": price,
                "order_type": order_type if isinstance(order_type, str) else "custom"
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
        positions = user_state.get("positions", user_state.get("assetPositions", []))
        
        # Calculate unrealized PnL for each position
        for position in positions:
            pos_dict = position.get("position", position)
            entry_px = float(pos_dict.get("entryPx", 0.0))
            mark_px = float(position.get("markPx", pos_dict.get("markPx", entry_px)))
            szi = float(pos_dict.get("szi", pos_dict.get("size", 0.0)))
            direction = pos_dict.get("dir", "LONG")
            position["unrealized_pnl"] = (mark_px - entry_px) * szi * (-1 if direction == "SHORT" else 1)
        
        total_val = sum(float(p.get("position", p).get("szi", 0.0)) * float(p.get("markPx", 0.0)) for p in positions)
        return {
            "status": "success",
            "data": positions,
            "metadata": {
                "count": len(positions),
                "total_value": total_val
            }
        }
    except Exception as e:
        logger.error(f"Position retrieval failed: {str(e)}")
        return {
            "status": "error",
            "message": str(e),
            "error_type": "position_retrieval"
        }

def set_leverage(exchange, leverage: int, symbol: str = "BTC") -> Dict[str, Any]:
    """
    Set leverage for perpetual trading with validation.
    
    Args:
        exchange: Hyperliquid Exchange instance
        leverage: Desired leverage (1-100)
        symbol: Trading symbol (e.g., "BTC")
        
    Returns:
        Leverage update result
    """
    try:
        # Validate leverage
        if not 1 <= leverage <= 100:
            raise ValueError("Leverage must be between 1-100")
            
        result = exchange.update_leverage(leverage, symbol)
        return {
            "status": "success",
            "data": result,
            "metadata": {"leverage": leverage, "symbol": symbol}
        }
    except Exception as e:
        logger.error(f"Leverage update failed: {str(e)}")
        return {
            "status": "error",
            "message": str(e),
            "error_type": "leverage_update"
        }
