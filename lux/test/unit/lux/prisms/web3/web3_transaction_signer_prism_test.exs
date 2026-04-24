defmodule Lux.Prisms.Web3.Web3TransactionSignerPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.Web3TransactionSignerPrism

  describe "handler/2" do
    test "returns queue status" do
      result = Web3TransactionSignerPrism.handler(%{"action" => "queue_status"}, %{})
      assert match?({:ok, _}, result)
    end
  end
end
