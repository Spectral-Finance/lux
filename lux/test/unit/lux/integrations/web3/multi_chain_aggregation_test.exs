defmodule Lux.Integrations.Web3.MultiChainAggregationTest do
  use UnitCase, async: true

  alias Lux.Integrations.Web3.MultiChainAggregation

  test "builds request plans for multiple chains and normalized log filters" do
    plan =
      MultiChainAggregation.plan_requests(
        [:ethereum, %{slug: :polygon, rpc_url: "https://polygon.example"}],
        actions: [:latest_block, :logs],
        filter: %{address: "0xABC", from_block: 100, to_block: "latest", topics: ["0xtopic"]},
        request_id_start: 10
      )

    assert plan.summary.request_count == 4
    assert plan.filter.address == ["0xabc"]
    assert Enum.map(plan.requests, & &1.payload.id) == [10, 11, 12, 13]
    assert Enum.any?(plan.requests, &(&1.payload.method == "eth_getLogs"))
  end

  test "aggregates latest blocks, logs, health, performance, and retention" do
    dataset =
      MultiChainAggregation.aggregate_responses(
        [
          %{chain: :ethereum, type: :latest_block, result: "0x10", latency_ms: 100},
          %{
            chain: :polygon,
            type: :logs,
            latency_ms: 250,
            result: [
              %{
                address: "0xabc",
                topics: ["0xtopic"],
                data: "0x",
                blockNumber: "0x20",
                transactionHash: "0xhash",
                logIndex: "0x1"
              }
            ]
          },
          %{
            chain: :bsc,
            type: :logs,
            error: %{code: -32_000, message: "rate limited"},
            latency_ms: 500
          }
        ],
        generated_at: "2026-05-14T00:00:00Z",
        retention: %{logs: 14}
      )

    assert dataset.generated_at == "2026-05-14T00:00:00Z"
    assert dataset.latest_blocks == %{ethereum: 16}
    assert [%{chain: :polygon, address: "0xabc", block_number: 32, log_index: 1}] = dataset.logs
    assert dataset.health.failed_responses == 1
    assert dataset.performance.p95_latency_ms == 500
    assert dataset.retention.policy_days.logs == 14
  end

  test "queries aggregated logs by chain, address, and topic" do
    dataset = %{
      logs: [
        %{chain: :ethereum, address: "0xabc", topics: ["0x1"], block_number: 1},
        %{chain: :polygon, address: "0xdef", topics: ["0x2"], block_number: 2}
      ]
    }

    result =
      MultiChainAggregation.query(dataset, chain: :ethereum, address: "0xabc", topic: "0x1")

    assert result.rows == [
             %{chain: :ethereum, address: "0xabc", topics: ["0x1"], block_number: 1}
           ]

    assert result.summary.returned == 1
  end
end
