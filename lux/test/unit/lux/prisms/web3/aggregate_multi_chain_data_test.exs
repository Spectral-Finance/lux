defmodule Lux.Prisms.Web3.AggregateMultiChainDataTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3.AggregateMultiChainData

  test "returns a snapshot and stream payload" do
    params = %{
      chains: [%{name: "ethereum", chain_id: 1}],
      blocks: [%{chain: "ethereum", number: 1, hash: "0xabc"}],
      transactions: [],
      events: []
    }

    assert {:ok, %{snapshot: snapshot, stream_payload: payload}} =
             AggregateMultiChainData.handler(params, nil)

    assert length(snapshot.chains) == 1
    assert payload.type == "multi_chain_snapshot"
  end
end
