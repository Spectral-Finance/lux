"""Schema definition for smart contract data.

This schema defines the structure for smart contract metadata,
including contract address, ABI, bytecode, and deployment information.
"""

from lux_sdk.signals import SignalSchema

class SmartContractSchema(SignalSchema):
    """Schema for smart contract data and interactions."""
    
    def __init__(self):
        """Initialize the SmartContractSchema."""
        super().__init__(
            name="smart_contract",
            version="1.0",
            description="Schema for smart contract metadata and interactions",
            schema={
                "type": "object",
                "properties": {
                    "timestamp": {
                        "type": "string",
                        "format": "date-time",
                        "description": "When the contract was deployed or last updated"
                    },
                    "contract_address": {
                        "type": "string",
                        "pattern": "^0x[a-fA-F0-9]{40}$",
                        "description": "The deployed contract address"
                    },
                    "contract_name": {
                        "type": "string",
                        "description": "Name of the smart contract"
                    },
                    "chain_id": {
                        "type": "integer",
                        "description": "The blockchain network ID where the contract is deployed"
                    },
                    "abi": {
                        "type": "array",
                        "description": "Contract ABI (Application Binary Interface)",
                        "items": {
                            "type": "object",
                            "properties": {
                                "type": {
                                    "type": "string",
                                    "enum": ["function", "event", "constructor", "fallback", "receive"]
                                },
                                "name": {
                                    "type": "string"
                                },
                                "inputs": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "name": {"type": "string"},
                                            "type": {"type": "string"},
                                            "indexed": {"type": "boolean"}
                                        },
                                        "required": ["type"]
                                    }
                                },
                                "outputs": {
                                    "type": "array",
                                    "items": {
                                        "type": "object",
                                        "properties": {
                                            "name": {"type": "string"},
                                            "type": {"type": "string"}
                                        },
                                        "required": ["type"]
                                    }
                                },
                                "stateMutability": {
                                    "type": "string",
                                    "enum": ["pure", "view", "nonpayable", "payable"]
                                }
                            },
                            "required": ["type"]
                        }
                    },
                    "bytecode": {
                        "type": "string",
                        "pattern": "^0x[a-fA-F0-9]*$",
                        "description": "Contract bytecode"
                    },
                    "source_code": {
                        "type": "string",
                        "description": "Contract source code"
                    },
                    "compiler": {
                        "type": "object",
                        "properties": {
                            "name": {
                                "type": "string",
                                "description": "Compiler name (e.g., 'solc')"
                            },
                            "version": {
                                "type": "string",
                                "description": "Compiler version"
                            },
                            "settings": {
                                "type": "object",
                                "description": "Compiler settings used"
                            }
                        },
                        "required": ["name", "version"]
                    },
                    "deployment": {
                        "type": "object",
                        "properties": {
                            "deployer": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{40}$",
                                "description": "Address that deployed the contract"
                            },
                            "transaction_hash": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{64}$",
                                "description": "Transaction hash of the deployment"
                            },
                            "block_number": {
                                "type": "integer",
                                "description": "Block number of deployment"
                            },
                            "constructor_arguments": {
                                "type": "array",
                                "description": "Arguments passed to the constructor"
                            }
                        },
                        "required": ["deployer", "transaction_hash", "block_number"]
                    },
                    "verified": {
                        "type": "boolean",
                        "description": "Whether the contract is verified on block explorer"
                    },
                    "proxy": {
                        "type": "object",
                        "properties": {
                            "is_proxy": {
                                "type": "boolean",
                                "description": "Whether this is a proxy contract"
                            },
                            "implementation_address": {
                                "type": "string",
                                "pattern": "^0x[a-fA-F0-9]{40}$",
                                "description": "Address of the implementation contract"
                            },
                            "proxy_type": {
                                "type": "string",
                                "enum": ["transparent", "uups", "beacon"],
                                "description": "Type of proxy pattern used"
                            }
                        }
                    },
                    "metadata": {
                        "type": "object",
                        "properties": {
                            "license": {
                                "type": "string",
                                "description": "Contract license"
                            },
                            "authors": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Contract authors"
                            },
                            "documentation": {
                                "type": "string",
                                "description": "Link to contract documentation"
                            },
                            "tags": {
                                "type": "array",
                                "items": {"type": "string"},
                                "description": "Contract tags/categories"
                            }
                        }
                    }
                },
                "required": [
                    "timestamp",
                    "contract_address",
                    "contract_name",
                    "chain_id",
                    "abi",
                    "bytecode"
                ]
            }
        ) 