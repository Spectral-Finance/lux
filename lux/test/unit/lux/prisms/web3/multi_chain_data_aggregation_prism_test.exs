defmodule Lux.Prisms.Web3.MultiChainDataAggregationPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3.MultiChainDataAggregationPrism

  @usdc "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
  @transfer_topic "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  test "returns a safe multi-chain aggregation plan" do
    assert {:ok, result} =
             MultiChainDataAggregationPrism.run(%{
               chains: ["ethereum", "polygon"],
               event_filters: [
                 %{name: "usdc_transfers", address: @usdc, topic: @transfer_topic}
               ],
               poll_interval_ms: 15_000
             })

    assert result.status == "planned"
    assert length(result.latest_block_requests) == 2
    assert result.subscription_plan.poll_interval_ms == 15_000
    assert length(result.subscription_plan.rpc_requests) == 2
    assert result.retention.archive_strategy == :compact_to_daily_partitions
  end

  test "returns an error for unsupported chains" do
    assert {:error, {:unsupported_chain, "not-a-chain"}} =
             MultiChainDataAggregationPrism.run(%{chains: ["not-a-chain"]})
  end
end
