"""Web3 schemas for blockchain and decentralized application interactions.

This module provides schemas for blockchain transactions, smart contracts,
NFTs, DeFi operations, and other Web3-related data structures.
"""

from lux_sdk.schemas.web3.transaction import TransactionSchema
from lux_sdk.schemas.web3.smart_contract import SmartContractSchema
from lux_sdk.schemas.web3.nft import NFTMetadataSchema
from lux_sdk.schemas.web3.wallet import WalletStateSchema
from lux_sdk.schemas.web3.defi import DeFiPositionSchema

__all__ = [
    'TransactionSchema',
    'SmartContractSchema',
    'NFTMetadataSchema',
    'WalletStateSchema',
    'DeFiPositionSchema'
] 