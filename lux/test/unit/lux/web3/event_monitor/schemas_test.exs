defmodule Lux.Web3.EventMonitor.SchemasTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.EventMonitor.Schemas.{Subscription, MonitoredEvent, WebhookDelivery, FilterPattern}
  alias Lux.Web3.EventMonitor.Schemas

  describe "Subscription struct" do
    test "instantiates with valid fields" do
      sub = %Subscription{
        id: "sub_1",
        chain_id: 1,
        chain: :ethereum,
        contract_address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
        event_name: "Transfer",
        status: :active
      }

      assert sub.id == "sub_1"
      assert sub.chain == :ethereum
      assert sub.status == :active
    end
  end

  describe "MonitoredEvent struct" do
    test "instantiates and normalizes composite event id" do
      evt_id = Schemas.generate_event_id(1, "0xabcdef123456", 5)
      assert evt_id == "evt_1_abcdef123456_5"

      event = %MonitoredEvent{
        id: evt_id,
        subscription_id: "sub_1",
        chain_id: 1,
        chain: :ethereum,
        contract_address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
        tx_hash: "0xabcdef123456",
        block_number: 123_456,
        decoded_params: %{value: 1000}
      }

      assert event.id == "evt_1_abcdef123456_5"
      assert event.decoded_params[:value] == 1000
    end
  end

  describe "Address normalization" do
    test "normalizes lowercase and 0x prefix" do
      assert Schemas.normalize_address("0xdAC17F958D2ee523a2206206994597C13D831ec7") ==
               "0xdac17f958d2ee523a2206206994597c13d831ec7"

      assert Schemas.normalize_address("dac17f958d2ee523a2206206994597c13d831ec7") ==
               "0xdac17f958d2ee523a2206206994597c13d831ec7"

      assert Schemas.normalize_address(nil) == nil
    end
  end
end
