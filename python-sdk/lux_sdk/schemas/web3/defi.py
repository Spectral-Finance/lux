"""Schema definition for DeFi (Decentralized Finance) positions.

This schema defines the structure for DeFi positions and investments,
including liquidity positions, staking, lending, and borrowing.
"""

from lux_sdk.signals import SignalSchema

class DeFiPositionSchema(SignalSchema):
    """Schema for DeFi positions and investments."""
    
    def __init__(self):
        """Initialize the DeFiPositionSchema."""
        super().__init__(
            name="defi_position",
            version="1.0",
            description="Schema for DeFi positions and investments",
            schema={
                "type": "object",
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the position state was captured"
                    },
                    "position_id": {
                        "type": "string",
                        "description": "Unique identifier for the position"
                    },
                    "protocol": {
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Protocol name"
                            },
                            "address": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{40}$",
                                "description": "Protocol contract address"
                            },
                            "chain_id": {
                                "type": "integer",
                                "description": "Blockchain network ID"
                            },
                            "type": {
                                "type": "string",
                                "enum": ["dex", "lending", "yield", "options", "derivatives", "insurance"],
                                "description": "Protocol type"
                            }
                        },
                        "required": ["name", "address", "chain_id", "type"]
                    },
                    "position_type": {
                        "type": "string",
                        "enum": [
                            "liquidity",
                            "farming",
                            "staking",
                            "lending",
                            "borrowing",
                            "options",
                            "perpetual",
                            "insurance"
                        ],
                        "description": "Type of DeFi position"
                    },
                    "owner": {
                        "type": "string",
                        "pattern": "^0x[a-fA-F0-9]{40}$",
                        "description": "Position owner address"
                    },
                    "liquidity": {
                        "type": "object",
                        "properties": {
                            "pool_address": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{40}$"
                            },
                            "token0": {
                                "type": "object",
                                "properties": {
                                    "address": {
                                        "type": "string",
                                        "pattern": "^0x[a-fA-F0-9]{40}$"
                                    },
                                    "symbol": {"type": "string"},
                                    "amount": {"type": "string"}
                                },
                                "required": ["address", "symbol", "amount"]
                            },
                            "token1": {
                                "type": "object",
                                "properties": {
                                    "address": {
                                        "type": "string",
                                        "pattern": "^0x[a-fA-F0-9]{40}$"
                                    },
                                    "symbol": {"type": "string"},
                                    "amount": {"type": "string"}
                                },
                                "required": ["address", "symbol", "amount"]
                            },
                            "fee_tier": {
                                "type": "integer",
                                "description": "Fee tier in basis points"
                            }
                        }
                    },
                    "farming": {
                        "type": "object",
                        "properties": {
                            "farm_address": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{40}$"
                            },
                            "staked_token": {
                                "type": "object",
                                "properties": {
                                    "address": {
                                        "type": "string",
                                        "pattern": "^0x[a-fA-F0-9]{40}$"
                                    },
                                    "symbol": {"type": "string"},
                                    "amount": {"type": "string"}
                                },
                                "required": ["address", "symbol", "amount"]
                            },
                            "reward_tokens": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "address": {
                                            "type": "string",
                                            "pattern": "^0x[a-fA-F0-9]{40}$"
                                        },
                                        "symbol": {"type": "string"},
                                        "amount": {"type": "string"},
                                        "unclaimed": {"type": "string"}
                                    },
                                    "required": ["address", "symbol", "amount"]
                                }
                            }
                        }
                    },
                    "lending": {
                        "type": "object",
                        "properties": {
                            "market_address": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{40}$"
                            },
                            "supplied_token": {
                                "type": "object",
                                "properties": {
                                    "address": {
                                        "type": "string",
                                        "pattern": "^0x[a-fA-F0-9]{40}$"
                                    },
                                    "symbol": {"type": "string"},
                                    "amount": {"type": "string"},
                                    "apy": {"type": "number"}
                                },
                                "required": ["address", "symbol", "amount", "apy"]
                            }
                        }
                    },
                    "borrowing": {
                        "type": "object",
                        "properties": {
                            "market_address": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{40}$"
                            },
                            "borrowed_token": {
                                "type": "object",
                                "properties": {
                                    "address": {
                                        "type": "string",
                                        "pattern": "^0x[a-fA-F0-9]{40}$"
                                    },
                                    "symbol": {"type": "string"},
                                    "amount": {"type": "string"},
                                    "apr": {"type": "number"}
                                },
                                "required": ["address", "symbol", "amount", "apr"]
                            },
                            "collateral": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "address": {
                                            "type": "string",
                                            "pattern": "^0x[a-fA-F0-9]{40}$"
                                        },
                                        "symbol": {"type": "string"},
                                        "amount": {"type": "string"},
                                        "factor": {"type": "number"}
                                    },
                                    "required": ["address", "symbol", "amount", "factor"]
                                }
                            }
                        }
                    },
                    "entry": {
                        "type": "object",
                        "properties": {
                            "timestamp": {
                                "type": "string",
                                "format": "date-time"
                            },
                            "transaction_hash": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{64}$"
                            },
                            "block_number": {
                                "type": "integer"
                            }
                        }
                    },
                    "metrics": {
                        "type": "object",
                        "properties": {
                            "total_value_locked_usd": {
                                "type": "number",
                                "description": "Total value locked in USD"
                            },
                            "daily_yield_usd": {
                                "type": "number",
                                "description": "Daily yield in USD"
                            },
                            "apy_percent": {
                                "type": "number",
                                "description": "Annual percentage yield"
                            },
                            "health_factor": {
                                "type": "number",
                                "description": "Position health factor"
                            }
                        }
                    },
                    "risks": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": [
                                        "impermanent_loss",
                                        "liquidation",
                                        "smart_contract",
                                        "oracle",
                                        "regulatory"
                                    ]
                                },
                                "level": {
                                    "type": "string",
                                    "enum": ["low", "medium", "high"]
                                },
                                "description": {"type": "string"}
                            },
                            "required": ["type", "level"]
                        }
                    }
                },
                "required": [
                    "timestamp",
                    "position_id",
                    "protocol",
                    "position_type",
                    "owner"
                ]
            }
        ) 