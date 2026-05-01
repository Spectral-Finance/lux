defmodule Lux.Prisms.Web3.Web3MultiChainAggregatorPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.Web3MultiChainAggregatorPrism

  describe "handler/2" do
    test "gets chain status" do
      result = Web3MultiChainAggregatorPrism.handler(%{
        "action" => "chain_status",
        "chains" => ["ethereum", "base"]
      }, %{})
      assert match?({:ok, _} or {:error, _}, result)
    end
  end
end
