//! Integration tests for lux_core

use lux_core::{data_aggregation, prisms, eval, serialization, types};

#[test]
fn test_full_aggregation_pipeline() {
    // Create sample blocks
    let blocks = vec![
        data_aggregation::BlockInfo {
            number: 100,
            hash: "0xblock100".to_string(),
            parent_hash: "0xblock99".to_string(),
            timestamp: 1700000000,
            chain_id: 1,
            transaction_count: 150,
            gas_used: 15_000_000,
            gas_limit: 30_000_000,
            miner: "0xminer1".to_string(),
            base_fee_per_gas: Some(30_000_000_000),
            extra_data: None,
        },
        data_aggregation::BlockInfo {
            number: 101,
            hash: "0xblock101".to_string(),
            parent_hash: "0xblock100".to_string(),
            timestamp: 1700000012,
            chain_id: 1,
            transaction_count: 160,
            gas_used: 16_000_000,
            gas_limit: 30_000_000,
            miner: "0xminer2".to_string(),
            base_fee_per_gas: Some(31_000_000_000),
            extra_data: None,
        },
    ];

    // Aggregate
    let stats = data_aggregation::aggregate_blocks(&blocks, None);
    assert_eq!(stats.block_count, 2);
    assert_eq!(stats.chain_id, 1);
    assert_eq!(stats.total_transactions, 310);
    assert_eq!(stats.unique_miners, 2);
}

#[test]
fn test_prism_pipeline() {
    // Create a filter prism
    let prism = prisms::create_prism(
        "eth_filter",
        "data_filter",
        Some(serde_json::json!({
            "field": "chain_id",
            "value": 1
        })),
    );

    // Create input data
    let input = serde_json::json!([
        {"chain_id": 1, "name": "eth_tx1"},
        {"chain_id": 137, "name": "polygon_tx1"},
        {"chain_id": 1, "name": "eth_tx2"},
        {"chain_id": 56, "name": "bsc_tx1"},
    ]);

    // Handle prism
    let result = prisms::handle_prism(&prism, &input);
    assert_eq!(result.status, "success");
    assert!(result.output.is_some());

    let output = result.output.unwrap();
    let filtered = output.as_array().unwrap();
    assert_eq!(filtered.len(), 2); // Only chain_id 1 items
}

#[test]
fn test_evaluation_pipeline() {
    // Simple evaluation
    assert_eq!(eval::evaluate("2 + 2").unwrap(), "4");
    assert_eq!(eval::evaluate("10 * 10").unwrap(), "100");

    // With variables
    let mut vars = std::collections::HashMap::new();
    vars.insert("x".to_string(), "42".to_string());
    assert_eq!(eval::evaluate_with_variables("x", &vars).unwrap(), "42");
}

#[test]
fn test_serialization_pipeline() {
    // Hash
    let hash = serialization::compute_sha256("test data").unwrap();
    assert_eq!(hash.len(), 64); // SHA-256 produces 32 bytes = 64 hex chars

    // Checksum address
    let addr = "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae";
    let checksummed = serialization::eip55_checksum(addr).unwrap();
    assert_eq!(checksummed, "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe");
}

#[test]
fn test_chain_config() {
    // Test all supported chains
    let chains = types::ChainConfig::all_chains();
    assert_eq!(chains.len(), 7);

    for chain in &chains {
        assert!(!chain.name.is_empty());
        assert!(!chain.symbol.is_empty());
        assert!(!chain.rpc_endpoints.is_empty());
    }
}

#[test]
fn test_block_serialization_roundtrip() {
    let block = types::BlockData {
        number: 19_000_000,
        hash: "0xabc123".to_string(),
        parent_hash: "0xdef456".to_string(),
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
    let deserialized: types::BlockData = serde_json::from_str(&json).unwrap();
    assert_eq!(deserialized.number, block.number);
    assert_eq!(deserialized.chain_id, block.chain_id);
}

#[test]
fn test_transaction_serialization_roundtrip() {
    let tx = types::TransactionData {
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
    let deserialized: types::TransactionData = serde_json::from_str(&json).unwrap();
    assert_eq!(deserialized.nonce, tx.nonce);
    assert_eq!(deserialized.value, tx.value);
}

#[test]
fn test_normalize_block_chain_specific() {
    let block = data_aggregation::BlockInfo {
        number: 100,
        hash: "0xblock".to_string(),
        parent_hash: "0xparent".to_string(),
        timestamp: 1700000000,
        chain_id: 137,
        transaction_count: 100,
        gas_used: 10_000_000,
        gas_limit: 20_000_000,
        miner: "0xminer".to_string(),
        base_fee_per_gas: None,
        extra_data: None,
    };

    // Normalize for different chains
    let eth_normalized = data_aggregation::normalize_block(&block, 1);
    assert_eq!(eth_normalized.chain_name, "Ethereum");

    let poly_normalized = data_aggregation::normalize_block(&block, 137);
    assert_eq!(poly_normalized.chain_name, "Polygon");
}

#[test]
fn test_aggregate_prism_operations() {
    // Test sum
    let prism = prisms::create_prism("agg", "data_aggregate", Some(serde_json::json!({
        "field": "value",
        "operation": "sum"
    })));
    let input = serde_json::json!([
        {"value": 10},
        {"value": 20},
        {"value": 30}
    ]);
    let result = prisms::handle_prism(&prism, &input);
    assert_eq!(result.output.unwrap()["result"], 60.0);

    // Test average
    let prism = prisms::create_prism("agg", "data_aggregate", Some(serde_json::json!({
        "field": "value",
        "operation": "average"
    })));
    let result = prisms::handle_prism(&prism, &input);
    assert_eq!(result.output.unwrap()["result"], 20.0);

    // Test min
    let prism = prisms::create_prism("agg", "data_aggregate", Some(serde_json::json!({
        "field": "value",
        "operation": "min"
    })));
    let result = prisms::handle_prism(&prism, &input);
    assert_eq!(result.output.unwrap()["result"], 10.0);

    // Test max
    let prism = prisms::create_prism("agg", "data_aggregate", Some(serde_json::json!({
        "field": "value",
        "operation": "max"
    })));
    let result = prisms::handle_prism(&prism, &input);
    assert_eq!(result.output.unwrap()["result"], 30.0);
}
