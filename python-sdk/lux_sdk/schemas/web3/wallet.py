"""Schema definition for wallet state data.

This schema defines the structure for wallet state information,
including balances, tokens, NFTs, and transaction history.
"""

from lux_sdk.signals import SignalSchema

class WalletStateSchema(SignalSchema):
    """Schema for wallet state and balances."""
    
    def __init__(self):
        """Initialize the WalletStateSchema."""
        super().__init__(
            name="wallet_state",
            version="1.0",
            description="Schema for wallet state and balances",
            schema={
                "type": "object",
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the wallet state was captured"
                    },
                    "address": {
                        "type": "string",
                        "pattern": "^0x[a-fA-F0-9]{40}$",
                        "description": "The wallet address"
                    },
                    "chain_id": {
                        "type": "integer",
                        "description": "The blockchain network ID"
                    },
                    "native_balance": {
                        "type": "string",
                        "description": "Native token balance in wei"
                    },
                    "tokens": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "token_address": {
                                    "type": "string",
                                    "pattern": "^0x[a-fA-F0-9]{40}$"
                                },
                                "symbol": {
                                    "type": "string"
                                },
                                "name": {
                                    "type": "string"
                                },
                                "decimals": {
                                    "type": "integer"
                                },
                                "balance": {
                                    "type": "string"
                                },
                                "token_type": {
                                    "type": "string",
                                    "enum": ["ERC20", "ERC721", "ERC1155"]
                                },
                                "price_usd": {
                                    "type": "number"
                                }
                            },
                            "required": ["token_address", "symbol", "balance", "token_type"]
                        }
                    },
                    "nfts": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "token_address": {
                                    "type": "string",
                                    "pattern": "^0x[a-fA-F0-9]{40}$"
                                },
                                "token_id": {
                                    "type": "string"
                                },
                                "amount": {
                                    "type": "string",
                                    "description": "Amount owned (relevant for ERC1155)"
                                },
                                "token_uri": {
                                    "type": "string",
                                    "format": "uri"
                                },
                                "metadata": {
                                    "type": "object"
                                },
                                "approved": {
                                    "type": "object",
                                    "properties": {
                                        "approved_address": {
                                            "type": "string",
                                            "pattern": "^0x[a-fA-F0-9]{40}$"
                                        },
                                        "approved_all": {
                                            "type": "boolean"
                                        }
                                    }
                                }
                            },
                            "required": ["token_address", "token_id"]
                        }
                    },
                    "transaction_count": {
                        "type": "integer",
                        "description": "Total number of transactions sent"
                    },
                    "first_tx": {
                        "type": "object",
                        "properties": {
                            "hash": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{64}$"
                            },
                            "timestamp": {
                                "type": "string",
                                "format": "date-time"
                            },
                            "block_number": {
                                "type": "integer"
                            }
                        }
                    },
                    "last_tx": {
                        "type": "object",
                        "properties": {
                            "hash": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{64}$"
                            },
                            "timestamp": {
                                "type": "string",
                                "format": "date-time"
                            },
                            "block_number": {
                                "type": "integer"
                            }
                        }
                    },
                    "ens": {
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Primary ENS name"
                            },
                            "names": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "All ENS names owned by this address"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "labels": {
                                "type": "array",
                                "items": {
                                    "type": "string"
                                },
                                "description": "Labels/tags for this wallet"
                            },
                            "risk_score": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 100,
                                "description": "Risk score (0-100)"
                            },
                            "last_active": {
                                "type": "string",
                                "format": "date-time",
                                "description": "Last activity timestamp"
                            }
                        }
                    }
                },
                "required": [
                    "timestamp",
                    "address",
                    "chain_id",
                    "native_balance"
                ]
            }
        ) 