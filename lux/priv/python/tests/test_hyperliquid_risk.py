import pytest
from hyperliquid_utils import risk_management

def test_liquidation_risk_critical():
    position_data = {
        "status": "success",
        "data": [{
            "marginSummary": {"accountValue": "50"}
        }],
        "metadata": {"total_value": 10000}
    }
    
    result = risk_management.check_liquidation_risk(position_data, 0.1)
    assert result["risk_level"] == "critical"
    assert result["liquidation_probability"] > 0.9

def test_position_size_calculation():
    size = risk_management.calculate_position_size(
        account_value=10000,
        risk_per_trade=0.01,
        entry_price=2500,
        leverage=10
    )
    assert size == 0.4  # (10000 * 0.01 * 10) / 2500

def test_invalid_risk_per_trade():
    with pytest.raises(ValueError):
        risk_management.calculate_position_size(10000, 0.2, 2500, 10)
