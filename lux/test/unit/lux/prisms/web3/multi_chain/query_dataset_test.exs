defmodule Lux.Prisms.Web3.MultiChain.QueryDatasetTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3.MultiChain.QueryDataset

  test "filters dataset rows" do
    dataset = %{logs: [%{chain: :base, address: "0xabc", topics: ["0xaaa"]}]}

    assert {:ok, result} =
             QueryDataset.handler(
               %{dataset: dataset, type: :logs, chain: :base, address: "0xabc"},
               nil
             )

    assert result.summary.returned == 1
  end
end
