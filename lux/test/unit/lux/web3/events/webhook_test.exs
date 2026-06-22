defmodule Lux.Web3.Events.WebhookTest do
  use UnitAPICase, async: true
  alias Lux.Web3.Events.Webhook
  alias Lux.Web3.Events.Event
  alias Lux.Web3.Events.Subscription

  describe "valid_url?/1" do
    test "accepts http and https urls" do
      assert Webhook.valid_url?("http://localhost:3000/webhook")
      assert Webhook.valid_url?("https://hooks.example.com/events")
    end

    test "rejects invalid urls" do
      refute Webhook.valid_url?("not-a-url")
      refute Webhook.valid_url?("")
      refute Webhook.valid_url?(nil)
    end
  end

  describe "build_payload/2" do
    test "constructs webhook payload" do
      event = %Event{
        chain_id: 1,
        contract_address: "0x1234567890123456789012345678901234567890",
        transaction_hash: "0xabc",
        block_number: 12345,
        log_index: 1,
        topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],
        data: "0x",
        decoded_params: %{from: "0xaaa", to: "0xbbb", value: 100},
        timestamp: 1_628_736_144
      }

      sub = Subscription.new(%{
        id: "sub-1",
        contract_address: "0x1234567890123456789012345678901234567890",
        event_signatures: ["Transfer(address,address,uint256)"]
      })

      payload = Webhook.build_payload(event, sub)
      assert payload.event.chain_id == 1
      assert payload.event.contract_address == "0x1234567890123456789012345678901234567890"
      assert payload.event.block_number == 12345
      assert payload.event.topic0 == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      assert payload.event.decoded_params == %{from: "0xaaa", to: "0xbbb", value: 100}
      assert payload.subscription.id == "sub-1"
      assert is_map(payload.timestamp)
    end
  end
end
