//! Data aggregation primitives for multi-chain data processing
//!
//! This module provides high-performance Rust implementations of data
//! aggregation functions for blockchain data, including block and
//! transaction aggregation, normalization, and statistics.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Block information for aggregation
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BlockInfo {
    pub number: u64,
    pub hash: String,
    pub parent_hash: String,
    pub timestamp: u64,
    pub chain_id: u64,
    pub transaction_count: u64,
    pub gas_used: u64,
    pub gas_limit: u64,
    pub miner: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub base_fee_per_gas: Option<u64>,
}

/// Transaction information for aggregation
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransactionInfo {
    pub hash: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub block_number: Option<u64>,
    pub from: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub to: Option<String>,
    pub value: String,
    pub gas: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub gas_price: Option<u64>,
    pub nonce: u64,
    pub chain_id: u64,
}

/// Aggregated block statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BlockStats {
    pub chain_id: u64,
    pub block_count: u64,
    pub total_transactions: u64,
    pub total_gas_used: u64,
    pub average_gas_used: f64,
    pub min_block_number: u64,
    pub max_block_number: u64,
    pub average_block_time: Option<f64>,
    pub average_base_fee: Option<f64>,
    pub unique_miners: u64,
}

/// Aggregated transaction statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransactionStats {
    pub chain_id: u64,
    pub transaction_count: u64,
    pub total_value_wei: String,
    pub average_gas: f64,
    pub average_gas_price: Option<f64>,
    pub unique_senders: u64,
    pub unique_recipients: u64,
    pub contract_creations: u64,
}

/// Normalized block data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NormalizedBlock {
    pub number: String,
    pub hash: String,
    pub parent_hash: String,
    pub timestamp: String,  // ISO 8601
    pub chain_id: u64,
    pub chain_name: String,
    pub transaction_count: u64,
    pub gas_used: String,
    pub gas_limit: String,
    pub gas_usage_percent: f64,
    pub miner: String,
    pub base_fee_gwei: Option<String>,
    pub extra_data: Option<String>,
}

/// Normalized transaction data
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NormalizedTransaction {
    pub hash: String,
    pub block_number: Option<String>,
    pub from: String,
    pub to: Option<String>,
    pub value_ether: String,
    pub value_gwei: String,
    pub gas: u64,
    pub gas_price_gwei: Option<String>,
    pub max_fee_gwei: Option<String>,
    pub nonce: u64,
    pub chain_id: u64,
    pub chain_name: String,
    pub transaction_type: String,
    pub input_length: u64,
}

/// Get chain name from chain ID
fn chain_name(chain_id: u64) -> String {
    match chain_id {
        1 => "Ethereum".to_string(),
        137 => "Polygon".to_string(),
        56 => "BNB Smart Chain".to_string(),
        42161 => "Arbitrum One".to_string(),
        10 => "Optimism".to_string(),
        43114 => "Avalanche".to_string(),
        250 => "Fantom".to_string(),
        _ => format!("Chain-{}", chain_id),
    }
}

/// Aggregate block data and compute statistics
pub fn aggregate_blocks(blocks: &[BlockInfo], chain_filter: Option<u64>) -> BlockStats {
    let filtered: Vec<&BlockInfo> = blocks
        .iter()
        .filter(|b| chain_filter.map_or(true, |cid| b.chain_id == cid))
        .collect();

    if filtered.is_empty() {
        return BlockStats {
            chain_id: chain_filter.unwrap_or(0),
            block_count: 0,
            total_transactions: 0,
            total_gas_used: 0,
            average_gas_used: 0.0,
            min_block_number: 0,
            max_block_number: 0,
            average_block_time: None,
            average_base_fee: None,
            unique_miners: 0,
        };
    }

    let total_txs: u64 = filtered.iter().map(|b| b.transaction_count).sum();
    let total_gas: u64 = filtered.iter().map(|b| b.gas_used).sum();
    let min_block = filtered.iter().map(|b| b.number).min().unwrap_or(0);
    let max_block = filtered.iter().map(|b| b.number).max().unwrap_or(0);

    let unique_miners: std::collections::HashSet<&String> =
        filtered.iter().map(|b| &b.miner).collect();

    let avg_block_time = if filtered.len() > 1 {
        let mut timestamps: Vec<u64> = filtered.iter().map(|b| b.timestamp).collect();
        timestamps.sort();
        let time_diff = timestamps.last().unwrap_or(&0) - timestamps.first().unwrap_or(&0);
        Some(time_diff as f64 / (filtered.len() as f64 - 1.0))
    } else {
        None
    };

    let avg_base_fee = if filtered.iter().any(|b| b.base_fee_per_gas.is_some()) {
        let fees: Vec<f64> = filtered
            .iter()
            .filter_map(|b| b.base_fee_per_gas.map(|f| f as f64))
            .collect();
        if fees.is_empty() {
            None
        } else {
            Some(fees.iter().sum::<f64>() / fees.len() as f64)
        }
    } else {
        None
    };

    BlockStats {
        chain_id: chain_filter.unwrap_or(filtered[0].chain_id),
        block_count: filtered.len() as u64,
        total_transactions: total_txs,
        total_gas_used: total_gas,
        average_gas_used: total_gas as f64 / filtered.len() as f64,
        min_block_number: min_block,
        max_block_number: max_block,
        average_block_time: avg_block_time,
        average_base_fee: avg_base_fee,
        unique_miners: unique_miners.len() as u64,
    }
}

/// Aggregate transaction data and compute statistics
pub fn aggregate_transactions(txs: &[TransactionInfo]) -> TransactionStats {
    if txs.is_empty() {
        return TransactionStats {
            chain_id: 0,
            transaction_count: 0,
            total_value_wei: "0".to_string(),
            average_gas: 0.0,
            average_gas_price: None,
            unique_senders: 0,
            unique_recipients: 0,
            contract_creations: 0,
        };
    }

    let chain_id = txs[0].chain_id;
    let total_gas: u64 = txs.iter().map(|t| t.gas).sum();

    let unique_senders: std::collections::HashSet<&String> =
        txs.iter().map(|t| &t.from).collect();

    let unique_recipients: std::collections::HashSet<&Option<String>> =
        txs.iter().map(|t| &t.to).collect();

    let contract_creations = txs.iter().filter(|t| t.to.is_none()).count() as u64;

    let avg_gas_price = if txs.iter().any(|t| t.gas_price.is_some()) {
        let prices: Vec<f64> = txs
            .iter()
            .filter_map(|t| t.gas_price.map(|p| p as f64))
            .collect();
        if prices.is_empty() {
            None
        } else {
            Some(prices.iter().sum::<f64>() / prices.len() as f64)
        }
    } else {
        None
    };

    // Sum values (simplified - in production would use big integer arithmetic)
    let total_value: u128 = txs
        .iter()
        .filter_map(|t| t.value.parse::<u128>().ok())
        .sum();

    TransactionStats {
        chain_id,
        transaction_count: txs.len() as u64,
        total_value_wei: total_value.to_string(),
        average_gas: total_gas as f64 / txs.len() as f64,
        average_gas_price: avg_gas_price,
        unique_senders: unique_senders.len() as u64,
        unique_recipients: unique_recipients.len() as u64 - if contract_creations > 0 { 1 } else { 0 },
        contract_creations,
    }
}

/// Normalize block data to standard format
pub fn normalize_block(block: &BlockInfo, chain_id: u64) -> NormalizedBlock {
    let gas_usage_pct = if block.gas_limit > 0 {
        (block.gas_used as f64 / block.gas_limit as f64) * 100.0
    } else {
        0.0
    };

    let base_fee_gwei = block.base_fee_per_gas.map(|f| {
        format!("{:.4}", f as f64 / 1_000_000_000.0)
    });

    NormalizedBlock {
        number: block.number.to_string(),
        hash: block.hash.clone(),
        parent_hash: block.parent_hash.clone(),
        timestamp: format_timestamp(block.timestamp),
        chain_id,
        chain_name: chain_name(chain_id),
        transaction_count: block.transaction_count,
        gas_used: block.gas_used.to_string(),
        gas_limit: block.gas_limit.to_string(),
        gas_usage_percent: gas_usage_pct,
        miner: block.miner.clone(),
        base_fee_gwei,
        extra_data: block.extra_data.clone(),
    }
}

/// Normalize transaction data to standard format
pub fn normalize_transaction(tx: &TransactionInfo, chain_id: u64) -> NormalizedTransaction {
    let value_wei: u128 = tx.value.parse().unwrap_or(0);
    let value_ether = format!("{:.18}", value_wei as f64 / 1e18);
    let value_gwei = format!("{:.9}", value_wei as f64 / 1e9);

    let tx_type = match tx.r#type {
        Some(0) => "legacy".to_string(),
        Some(1) => "access_list".to_string(),
        Some(2) => "eip1559".to_string(),
        _ => "unknown".to_string(),
    };

    let gas_price_gwei = tx.gas_price.map(|p| format!("{:.9}", p as f64 / 1e9));
    let max_fee_gwei = tx.max_fee_per_gas.map(|p| format!("{:.9}", p as f64 / 1e9));

    let input_length = if tx.input.starts_with("0x") {
        (tx.input.len() - 2) / 2
    } else {
        tx.input.len() / 2
    } as u64;

    NormalizedTransaction {
        hash: tx.hash.clone(),
        block_number: tx.block_number.map(|n| n.to_string()),
        from: tx.from.clone(),
        to: tx.to.clone(),
        value_ether,
        value_gwei,
        gas: tx.gas,
        gas_price_gwei,
        max_fee_gwei,
        nonce: tx.nonce,
        chain_id,
        chain_name: chain_name(chain_id),
        transaction_type: tx_type,
        input_length,
    }
}

/// Format Unix timestamp to ISO 8601 string
fn format_timestamp(timestamp: u64) -> String {
    // Simplified timestamp formatting
    // In production, would use chrono for proper formatting
    let seconds = timestamp % 60;
    let minutes = (timestamp / 60) % 60;
    let hours = (timestamp / 3600) % 24;
    let days = timestamp / 86400;

    // Epoch-based calculation (approximate)
    let total_days = days as i64;
    let mut year = 1970i64;
    let mut remaining_days = total_days;

    while remaining_days > 365 {
        let is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        let days_in_year = if is_leap { 366 } else { 365 };
        if remaining_days >= days_in_year {
            remaining_days -= days_in_year;
            year += 1;
        } else {
            break;
        }
    }

    let months = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    let mut month_days = months.to_vec();
    if is_leap {
        month_days[1] = 29;
    }

    let mut month = 1;
    for &days_in_month in &month_days {
        if remaining_days < days_in_month as i64 {
            break;
        }
        remaining_days -= days_in_month as i64;
        month += 1;
    }
    let day = remaining_days + 1;

    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z",
        year, month, day, hours, minutes, seconds
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_block(number: u64, chain_id: u64) -> BlockInfo {
        BlockInfo {
            number,
            hash: format!("0xblock{}", number),
            parent_hash: format!("0xblock{}", number - 1),
            timestamp: 1700000000 + number * 12,
            chain_id,
            transaction_count: 100 + number,
            gas_used: 15_000_000,
            gas_limit: 30_000_000,
            miner: "0xminer".to_string(),
            base_fee_per_gas: Some(30_000_000_000),
            extra_data: None,
        }
    }

    fn sample_tx(hash: &str, chain_id: u64) -> TransactionInfo {
        TransactionInfo {
            hash: hash.to_string(),
            block_number: Some(19_000_000),
            from: "0xsender".to_string(),
            to: Some("0xreceiver".to_string()),
            value: "1000000000000000000".to_string(),
            gas: 21000,
            gas_price: Some(50_000_000_000),
            nonce: 1,
            chain_id,
        }
    }

    #[test]
    fn test_aggregate_blocks() {
        let blocks = vec![
            sample_block(100, 1),
            sample_block(101, 1),
            sample_block(102, 1),
        ];

        let stats = aggregate_blocks(&blocks, None);
        assert_eq!(stats.block_count, 3);
        assert_eq!(stats.chain_id, 1);
        assert!(stats.average_gas_used > 0.0);
    }

    #[test]
    fn test_aggregate_blocks_with_filter() {
        let blocks = vec![
            sample_block(100, 1),
            sample_block(100, 137),
            sample_block(101, 1),
        ];

        let eth_stats = aggregate_blocks(&blocks, Some(1));
        assert_eq!(eth_stats.block_count, 2);

        let poly_stats = aggregate_blocks(&blocks, Some(137));
        assert_eq!(poly_stats.block_count, 1);
    }

    #[test]
    fn test_aggregate_transactions() {
        let txs = vec![
            sample_tx("0xtx1", 1),
            sample_tx("0xtx2", 1),
        ];

        let stats = aggregate_transactions(&txs);
        assert_eq!(stats.transaction_count, 2);
        assert_eq!(stats.chain_id, 1);
        assert_eq!(stats.contract_creations, 0);
    }

    #[test]
    fn test_normalize_block() {
        let block = sample_block(100, 1);
        let normalized = normalize_block(&block, 1);
        assert_eq!(normalized.chain_name, "Ethereum");
        assert_eq!(normalized.gas_usage_percent, 50.0);
        assert!(normalized.base_fee_gwei.is_some());
    }

    #[test]
    fn test_normalize_transaction() {
        let tx = sample_tx("0xtx1", 1);
        let normalized = normalize_transaction(&tx, 1);
        assert_eq!(normalized.chain_name, "Ethereum");
        assert!(normalized.value_ether.contains("1.0"));
    }

    #[test]
    fn test_empty_aggregation() {
        let blocks: Vec<BlockInfo> = vec![];
        let stats = aggregate_blocks(&blocks, None);
        assert_eq!(stats.block_count, 0);

        let txs: Vec<TransactionInfo> = vec![];
        let stats = aggregate_transactions(&txs);
        assert_eq!(stats.transaction_count, 0);
    }
}
