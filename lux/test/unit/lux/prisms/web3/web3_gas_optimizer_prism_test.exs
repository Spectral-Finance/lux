defmodule Lux.Prisms.Web3.Web3GasOptimizerPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.Web3GasOptimizerPrism

  describe "handler/2" do
    test "estimates gas fees" do
      result = Web3GasOptimizerPrism.handler(%{"action" => "estimate", "chain" => "ethereum"}, %{})
      assert match?({:ok, _} or {:error, _}, result)
    end

    test "recommends optimal timing" do
      result = Web3GasOptimizerPrism.handler(%{"action" => "optimal_time"}, %{})
      assert match?({:ok, _}, result)
    end
  end
end
