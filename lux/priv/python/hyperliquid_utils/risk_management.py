import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

def check_liquidation_risk(position_data: Dict[str, Any], margin_threshold: float = 0.1) -> Dict[str, Any]:
    """
    Analyze liquidation risk based on position and margin data.
    
    Args:
        position_data: Position data from get_positions()
        margin_threshold: Minimum margin ratio threshold (default 10%)
        
    Returns:
        Risk assessment with liquidation probability
    """
    try:
        if position_data["status"] != "success":
            return {
                "status": "error",
                "message": "Invalid position data",
                "error_type": "risk_analysis"
            }
            
        positions = position_data["data"]
        total_value = position_data["metadata"]["total_value"]
        margin_ratio = float(positions[0]["marginSummary"]["accountValue"]) / total_value if total_value > 0 else 0
        
        # Risk assessment logic
        risk_level = "low"
        if margin_ratio < margin_threshold:
            risk_level = "critical"
        elif margin_ratio < margin_threshold * 2:
            risk_level = "high"
            
        return {
            "status": "success",
            "risk_level": risk_level,
            "margin_ratio": margin_ratio,
            "liquidation_probability": max(0, min(1, (margin_threshold - margin_ratio) / margin_threshold)),
            "recommended_actions": ["reduce_position", "add_margin"] if risk_level == "critical" else []
        }
    except Exception as e:
        logger.error(f"Risk analysis failed: {str(e)}")
        return {
            "status": "error",
            "message": str(e),
            "error_type": "risk_analysis"
        }

def calculate_position_size(account_value: float, risk_per_trade: float, entry_price: float, leverage: int) -> float:
    """
    Calculate position size based on risk management parameters.
    
    Args:
        account_value: Total account value
        risk_per_trade: Risk percentage per trade (0.01 = 1%)
        entry_price: Entry price of asset
        leverage: Desired leverage
        
    Returns:
        Position size in base currency
    """
    try:
        if not 0 < risk_per_trade <= 0.1:
            raise ValueError("Risk per trade must be between 0.1-10%")
            
        risk_amount = account_value * risk_per_trade
        return (risk_amount * leverage) / entry_price
    except Exception as e:
        logger.error(f"Position sizing failed: {str(e)}")
        raise