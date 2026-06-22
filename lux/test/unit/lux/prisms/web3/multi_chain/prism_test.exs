defmodule Lux.Prisms.Web3.MultiChain.PrismTest do
  use ExUnit.Case, async: false

  alias Lux.Integrations.Web3.MultiChain.Aggregator
  alias Lux.Prisms.Web3.MultiChain.QueryEvents
  alias Lux.Prisms.Web3.MultiChain.QueryBlocks

  setup do
    case Aggregator.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    Lux.Integrations.Web3.MultiChain.Storage.clear()
    :ok
  end

  test "query blocks prism" do
    Lux.Integrations.Web3.MultiChain.Storage.insert_block("1", %{"number" => "0x1", "timestamp" => 100})
    assert {:ok, %{status: "success", data: blocks}} = QueryBlocks.handler(%{}, %{})
    assert blocks["1"]["number"] == "0x1"
  end

  test "query events prism" do
    Lux.Integrations.Web3.MultiChain.Storage.insert_event("1", %{"transactionHash" => "0x123", "logIndex" => 0})
    assert {:ok, %{status: "success", count: 1, data: events}} = QueryEvents.handler(%{}, %{})
    assert length(events) == 1
  end
end
