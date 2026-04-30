//! Core data types for Lux framework
//!
//! This module defines the fundamental data structures used throughout
//! the Lux framework, including blocks, transactions, and events.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Represents a blockchain block
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BlockData {
    /// Block number
    pub number: u64,
    /// Block hash
    pub hash: String,
    /// Parent block hash
    pub parent_hash: String,
    /// Timestamp (Unix epoch seconds)
    pub timestamp: u64,
    /// Chain ID
    pub chain_id: u64,
    /// Number of transactions
    pub transaction_count: u64,
    /// Gas used
    pub gas_used: u64,
    /// Gas limit
    pub gas_limit: u64,
    /// Miner/validator address
    pub miner: String,
    /// Base fee per gas (EIP-1559)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub base_fee_per_gas: Option<u64>,
    /// Extra data
    #[serde(skip_serializing_if = "Option::is_none")]
    pub extra_data: Option<String>,
}

/// Represents a blockchain transaction
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransactionData {
    /// Transaction hash
    pub hash: String,
    /// Block number (if mined)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub block_number: Option<u64>,
    /// Transaction index in block
    #[serde(skip_serializing_if = "Option::is_none")]
    pub transaction_index: Option<u64>,
    /// Sender address
    pub from: String,
    /// Recipient address (None for contract creation)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub to: Option<String>,
    /// Value in wei
    pub value: String,
    /// Gas limit
    pub gas: u64,
    /// Max fee per gas (EIP-1559)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_fee_per_gas: Option<u64>,
    /// Max priority fee per gas (EIP-1559)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_priority_fee_per_gas: Option<u64>,
    /// Gas price (legacy)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gas_price: Option<u64>,
    /// Input data
    pub input: String,
    /// Nonce
    pub nonce: u64,
    /// Chain ID
    pub chain_id: u64,
    /// Transaction type (0=legacy, 1=access list, 2=EIP-1559)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub r#type: Option<u8>,
    /// Status (1=success, 0=reverted)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<u8>,
}

/// Represents a smart contract event log
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EventData {
    /// Log index
    pub log_index: u64,
    /// Transaction hash
    pub transaction_hash: String,
    /// Block number
    pub block_number: u64,
    /// Contract address
    pub address: String,
    /// Event topics
    pub topics: Vec<String>,
    /// Event data (hex encoded)
    pub data: String,
    /// Chain ID
    pub chain_id: u64,
    /// Whether the log was removed (reorg)
    pub removed: bool,
}

/// Result from a prism execution
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrismResult {
    /// Prism identifier
    pub prism_id: String,
    /// Prism name
    pub name: String,
    /// Execution status
    pub status: String,
    /// Output data
    pub output: Option<String>,
    /// Error message (if failed)
    pub error: Option<String>,
    /// Execution time in milliseconds
    pub execution_time_ms: f64,
    /// Metadata
    #[serde(skip_serializing_if = "Option::is_none")]
    pub metadata: Option<HashMap<String, String>>,
}

/// Chain-specific configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChainConfig {
    /// Chain ID
    pub chain_id: u64,
    /// Chain name
    pub name: String,
    /// Native currency symbol
    pub symbol: String,
    /// Block time in seconds
    pub block_time: f64,
    /// RPC endpoints
    pub rpc_endpoints: Vec<String>,
    /// Explorer URL template
    #[serde(skip_serializing_if = "Option::is_none")]
    pub explorer_url: Option<String>,
}

impl ChainConfig {
    /// Get default configuration for common chains
    pub fn for_chain(chain_id: u64) -> Option<Self> {
        match chain_id {
            1 => Some(Self {
                chain_id: 1,
                name: "Ethereum".to_string(),
                symbol: "ETH".to_string(),
                block_time: 12.0,
                rpc_endpoints: vec![
                    "https://eth.llamarpc.com".to_string(),
                    "https://rpc.ankr.com/eth".to_string(),
                ],
                explorer_url: Some("https://etherscan.io".to_string()),
            }),
            137 => Some(Self {
                chain_id: 137,
                name: "Polygon".to_string(),
                symbol: "MATIC".to_string(),
                block_time: 2.0,
                rpc_endpoints: vec![
                    "https://polygon-rpc.com".to_string(),
                    "https://rpc.ankr.com/polygon".to_string(),
                ],
                explorer_url: Some("https://polygonscan.com".to_string()),
            }),
            56 => Some(Self {
                chain_id: 56,
                name: "BNB Smart Chain".to_string(),
                symbol: "BNB".to_string(),
                block_time: 3.0,
                rpc_endpoints: vec![
                    "https://bsc-dataseed.binance.org".to_string(),
                    "https://rpc.ankr.com/bsc".to_string(),
                ],
                explorer_url: Some("https://bscscan.com".to_string()),
            }),
            42161 => Some(Self {
                chain_id: 42161,
                name: "Arbitrum One".to_string(),
                symbol: "ETH".to_string(),
                block_time: 0.5,
                rpc_endpoints: vec![
                    "https://arb1.arbitrum.io/rpc".to_string(),
                    "https://rpc.ankr.com/arbitrum".to_string(),
                ],
                explorer_url: Some("https://arbiscan.io".to_string()),
            }),
            10 => Some(Self {
                chain_id: 10,
                name: "Optimism".to_string(),
                symbol: "ETH".to_string(),
                block_time: 2.0,
                rpc_endpoints: vec![
                    "https://mainnet.optimism.io".to_string(),
                    "https://rpc.ankr.com/optimism".to_string(),
                ],
                explorer_url: Some("https://optimistic.etherscan.io".to_string()),
            }),
            43114 => Some(Self {
                chain_id: 43114,
                name: "Avalanche".to_string(),
                symbol: "AVAX".to_string(),
                block_time: 2.0,
                rpc_endpoints: vec![
                    "https://api.avax.network/ext/bc/C/rpc".to_string(),
                    "https://rpc.ankr.com/avalanche".to_string(),
                ],
                explorer_url: Some("https://snowtrace.io".to_string()),
            }),
            250 => Some(Self {
                chain_id: 250,
                name: "Fantom".to_string(),
                symbol: "FTM".to_string(),
                block_time: 1.0,
                rpc_endpoints: vec![
                    "https://rpc.ftm.tools".to_string(),
                    "https://rpc.ankr.com/fantom".to_string(),
                ],
                explorer_url: Some("https://ftmscan.com".to_string()),
            }),
            _ => None,
        }
    }

    /// Get all supported chain configurations
    pub fn all_chains() -> Vec<Self> {
        vec![1, 137, 56, 42161, 10, 43114, 250]
            .iter()
            .filter_map(|id| Self::for_chain(*id))
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_chain_config_ethereum() {
        let config = ChainConfig::for_chain(1).unwrap();
        assert_eq!(config.name, "Ethereum");
        assert_eq!(config.symbol, "ETH");
        assert_eq!(config.block_time, 12.0);
    }

    #[test]
    fn test_chain_config_polygon() {
        let config = ChainConfig::for_chain(137).unwrap();
        assert_eq!(config.name, "Polygon");
        assert_eq!(config.symbol, "MATIC");
    }

    #[test]
    fn test_chain_config_unknown() {
        assert!(ChainConfig::for_chain(999).is_none());
    }

    #[test]
    fn test_all_chains() {
        let chains = ChainConfig::all_chains();
        assert_eq!(chains.len(), 7);
    }

    #[test]
    fn test_block_serialization() {
        let block = BlockData {
            number: 19_000_000,
            hash: "0x1234".to_string(),
            parent_hash: "0x0000".to_string(),
            timestamp: 1700000000,
            chain_id: 1,
            transaction_count: 150,
            gas_used: 15_000_000,
            gas_limit: 30_000_000,
            miner: "0xminer".to_string(),
            base_fee_per_gas: Some(30_000_000_000),
            extra_data: None,
        };

        let json = serde_json::to_string(&block).unwrap();
        let deserialized: BlockData = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.number, 19_000_000);
        assert_eq!(deserialized.chain_id, 1);
    }

    #[test]
    fn test_transaction_serialization() {
        let tx = TransactionData {
            hash: "0xtxhash".to_string(),
            block_number: Some(19_000_000),
            transaction_index: Some(5),
            from: "0xsender".to_string(),
            to: Some("0xreceiver".to_string()),
            value: "1000000000000000000".to_string(),
            gas: 21000,
            max_fee_per_gas: Some(50_000_000_000),
            max_priority_fee_per_gas: Some(2_000_000_000),
            gas_price: None,
            input: "0x".to_string(),
            nonce: 42,
            chain_id: 1,
            r#type: Some(2),
            status: Some(1),
        };

        let json = serde_json::to_string(&tx).unwrap();
        let deserialized: TransactionData = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.nonce, 42);
        assert_eq!(deserialized.r#type, Some(2));
    }
}
