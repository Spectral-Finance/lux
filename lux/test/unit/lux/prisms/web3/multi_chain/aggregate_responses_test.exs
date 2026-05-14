defmodule Lux.Prisms.Web3.MultiChain.AggregateResponsesTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3.MultiChain.AggregateResponses

  test "returns an aggregated dataset" do
    assert {:ok, dataset} =
             AggregateResponses.handler(
               %{responses: [%{chain: :ethereum, type: :latest_block, result: "0x2"}]},
               nil
             )

    assert dataset.latest_blocks == %{ethereum: 2}
    assert dataset.health.successful_responses == 1
  end
end
