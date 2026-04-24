defmodule Lux.Prisms.Web3.Web3EventMonitorPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.Web3EventMonitorPrism

  describe "handler/2" do
    test "creates event subscription" do
      result = Web3EventMonitorPrism.handler(%{
        "action" => "subscribe",
        "chain" => "ethereum",
        "contract_address" => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        "event_signature" => "Transfer(address,address,uint256)"
      }, %{})
      assert match?({:ok, _}, result)
    end

    test "decodes event signature" do
      result = Web3EventMonitorPrism.handler(%{
        "action" => "decode_event",
        "event_signature" => "Transfer(address,address,uint256)"
      }, %{})
      assert match?({:ok, _}, result)
    end
  end
end
