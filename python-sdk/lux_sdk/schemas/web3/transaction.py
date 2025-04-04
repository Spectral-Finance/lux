"""Schema definition for blockchain transactions.

This schema defines the structure for blockchain transaction data,
including transaction hash, from/to addresses, value, gas details,
and transaction status.
"""

from lux_sdk.signals import SignalSchema

class TransactionSchema(SignalSchema):
    """Schema for blockchain transaction data."""
    
    def __init__(self):
        """Initialize the TransactionSchema."""
        super().__init__(
            name="transaction",
            version="1.0",
            description="Schema for blockchain transaction data",
            schema={
                "type": "object",
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the transaction was created/mined"
                    },
                    "transaction_hash": {
                        "type": "string",
                        "pattern": "^0x[a-fA-F0-9]{64}$",
                        "description": "The unique hash of the transaction"
                    },
                    "from_address": {
                        "type": "string",
                        "pattern": "^0x[a-fA-F0-9]{40}$",
                        "description": "The sender's address"
                    },
                    "to_address": {
                        "type": "string",
                        "pattern": "^0x[a-fA-F0-9]{40}$",
                        "description": "The recipient's address"
                    },
                    "value": {
                        "type": "string",
                        "description": "The transaction value in wei (as a string to handle large numbers)"
                    },
                    "gas_price": {
                        "type": "string",
                        "description": "Gas price in wei"
                    },
                    "gas_limit": {
                        "type": "string",
                        "description": "Maximum gas allowed for the transaction"
                    },
                    "gas_used": {
                        "type": "string",
                        "description": "Actual gas used by the transaction"
                    },
                    "nonce": {
                        "type": "integer",
                        "description": "The number of transactions sent from this address"
                    },
                    "block_number": {
                        "type": "integer",
                        "description": "Block number where this transaction was included"
                    },
                    "block_hash": {
                        "type": "string",
                        "pattern": "^0x[a-fA-F0-9]{64}$",
                        "description": "Hash of the block containing this transaction"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["pending", "success", "failed"],
                        "description": "Transaction status"
                    },
                    "chain_id": {
                        "type": "integer",
                        "description": "The ID of the blockchain network"
                    },
                    "input_data": {
                        "type": "string",
                        "description": "The input data for contract interactions"
                    },
                    "confirmations": {
                        "type": "integer",
                        "minimum": 0,
                        "description": "Number of block confirmations"
                    },
                    "error": {
                        "type": "string",
                        "description": "Error message if the transaction failed"
                    },
                    "metadata": {
                        "type": "object",
                        "description": "Additional transaction metadata",
                        "properties": {
                            "contract_address": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{40}$",
                                "description": "Created contract address (for contract creation)"
                            },
                            "token_transfers": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "token_address": {
                                            "type": "string",
                                            "pattern": "^0x[a-fA-F0-9]{40}$"
                                        },
                                        "from": {
                                            "type": "string",
                                            "pattern": "^0x[a-fA-F0-9]{40}$"
                                        },
                                        "to": {
                                            "type": "string",
                                            "pattern": "^0x[a-fA-F0-9]{40}$"
                                        },
                                        "value": {
                                            "type": "string"
                                        },
                                        "token_type": {
                                            "type": "string",
                                            "enum": ["ERC20", "ERC721", "ERC1155"]
                                        }
                                    },
                                    "required": ["token_address", "from", "to", "value", "token_type"]
                                }
                            }
                        }
                    }
                },
                "required": [
                    "timestamp",
                    "transaction_hash",
                    "from_address",
                    "to_address",
                    "value",
                    "gas_price",
                    "gas_limit",
                    "nonce",
                    "chain_id",
                    "status"
                ]
            }
        ) 