//! Benchmarks for lux_core

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use lux_core::{data_aggregation, prisms, eval, serialization};

fn bench_aggregate_blocks(c: &mut Criterion) {
    let blocks: Vec<data_aggregation::BlockInfo> = (0..1000)
        .map(|i| data_aggregation::BlockInfo {
            number: i,
            hash: format!("0xblock{}", i),
            parent_hash: format!("0xblock{}", i - 1),
            timestamp: 1700000000 + i * 12,
            chain_id: if i % 3 == 0 { 137 } else { 1 },
            transaction_count: 100 + (i % 200),
            gas_used: 15_000_000 + (i % 5_000_000),
            gas_limit: 30_000_000,
            miner: format!("0xminer{}", i % 10),
            base_fee_per_gas: Some(30_000_000_000 + (i as u64 * 100_000)),
            extra_data: None,
        })
        .collect();

    c.bench_function("aggregate_blocks_1000", |b| {
        b.iter(|| data_aggregation::aggregate_blocks(black_box(&blocks), None))
    });

    c.bench_function("aggregate_blocks_filtered", |b| {
        b.iter(|| data_aggregation::aggregate_blocks(black_box(&blocks), Some(1)))
    });
}

fn bench_aggregate_transactions(c: &mut Criterion) {
    let txs: Vec<data_aggregation::TransactionInfo> = (0..1000)
        .map(|i| data_aggregation::TransactionInfo {
            hash: format!("0xtx{}", i),
            block_number: Some(i / 10),
            from: format!("0xsender{}", i % 50),
            to: if i % 20 == 0 { None } else { Some(format!("0xreceiver{}", i % 100)) },
            value: format!("{}", 1_000_000_000_000_000_000u64 + i),
            gas: 21000 + (i % 100_000),
            gas_price: Some(50_000_000_000),
            nonce: i,
            chain_id: 1,
        })
        .collect();

    c.bench_function("aggregate_transactions_1000", |b| {
        b.iter(|| data_aggregation::aggregate_transactions(black_box(&txs)))
    });
}

fn bench_normalize_block(c: &mut Criterion) {
    let block = data_aggregation::BlockInfo {
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

    c.bench_function("normalize_block", |b| {
        b.iter(|| data_aggregation::normalize_block(black_box(&block), 1))
    });
}

fn bench_prism_filter(c: &mut Criterion) {
    let prism = prisms::create_prism("filter", "data_filter", Some(serde_json::json!({
        "field": "chain_id",
        "value": 1
    })));

    let input: serde_json::Value = serde_json::json!((0..1000).map(|i| {
        serde_json::json!({
            "chain_id": if i % 3 == 0 { 137 } else { 1 },
            "value": i
        })
    }).collect::<Vec<_>>());

    c.bench_function("prism_filter_1000", |b| {
        b.iter(|| prisms::handle_prism(black_box(&prism), black_box(&input)))
    });
}

fn bench_prism_aggregate(c: &mut Criterion) {
    let prism = prisms::create_prism("agg", "data_aggregate", Some(serde_json::json!({
        "field": "value",
        "operation": "sum"
    })));

    let input: serde_json::Value = serde_json::json!((0..1000).map(|i| {
        serde_json::json!({"value": i})
    }).collect::<Vec<_>>());

    c.bench_function("prism_aggregate_sum_1000", |b| {
        b.iter(|| prisms::handle_prism(black_box(&prism), black_box(&input)))
    });
}

fn bench_evaluate(c: &mut Criterion) {
    c.bench_function("evaluate_simple", |b| {
        b.iter(|| eval::evaluate(black_box("2 + 2 * 3")))
    });

    c.bench_function("evaluate_complex", |b| {
        b.iter(|| eval::evaluate(black_box("(100 + 200) * (300 - 150) / 10")))
    });
}

fn bench_sha256(c: &mut Criterion) {
    let data = "test data for hashing with some additional content to make it more realistic";

    c.bench_function("sha256_hash", |b| {
        b.iter(|| serialization::compute_sha256(black_box(data)))
    });
}

fn bench_eip55_checksum(c: &mut Criterion) {
    let address = "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae";

    c.bench_function("eip55_checksum", |b| {
        b.iter(|| serialization::eip55_checksum(black_box(address)))
    });
}

fn bench_block_serialization(c: &mut Criterion) {
    let block = data_aggregation::BlockInfo {
        number: 19_000_000,
        hash: "0xabc123def456".to_string(),
        parent_hash: "0xdef456abc123".to_string(),
        timestamp: 1700000000,
        chain_id: 1,
        transaction_count: 150,
        gas_used: 15_000_000,
        gas_limit: 30_000_000,
        miner: "0xminer123".to_string(),
        base_fee_per_gas: Some(30_000_000_000),
        extra_data: Some("0x".to_string()),
    };

    c.bench_function("block_serialize", |b| {
        b.iter(|| serde_json::to_string(black_box(&block)).unwrap())
    });

    let json = serde_json::to_string(&block).unwrap();
    c.bench_function("block_deserialize", |b| {
        b.iter(|| serde_json::from_str::<data_aggregation::BlockInfo>(black_box(&json)).unwrap())
    });
}

criterion_group!(
    benches,
    bench_aggregate_blocks,
    bench_aggregate_transactions,
    bench_normalize_block,
    bench_prism_filter,
    bench_prism_aggregate,
    bench_evaluate,
    bench_sha256,
    bench_eip55_checksum,
    bench_block_serialization,
);

criterion_main!(benches);
