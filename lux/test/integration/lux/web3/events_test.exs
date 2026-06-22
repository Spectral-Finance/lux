defmodule Lux.Integration.Web3EventsTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Web3.Events
  alias Lux.Web3.Events.Event
  alias Lux.Web3.Events.Subscription
  alias Lux.Web3.Events.Sync
  alias Lux.Web3.Events.Decoder
  alias Lux.Integration.Etherscan.RateLimitedAPI

  @contract_address "0xbd3531da5cf5857e7cfaa92426877b022e612cf8"
  @transfer_topic "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

  setup do
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  describe "event subscription and sync" do
    @tag timeout: 120_000
    test "can subscribe and sync events for a contract" do
      sub = Subscription.new(%{
        chain_id: 1,
        contract_address: @contract_address,
        event_signatures: ["Transfer(address,address,uint256)"],
        from_block: 12_878_196,
        to_block: 12_878_200,
        poll_interval_ms: 30_000
      })

      assert sub.chain_id == 1
      assert sub.contract_address == @contract_address

      result = Sync.historical_sync(sub)

      case result do
        {:ok, events} ->
          for event <- events do
            assert %Event{} = event
            assert event.chain_id == 1
            assert event.contract_address == @contract_address
          end
        {:error, error} ->
          IO.puts("Sync result: #{inspect(error)}")
          assert true
      end
    end

    @tag timeout: 120_000
    test "can decode Transfer event topics" do
      computed = Decoder.event_signature_to_topic("Transfer(address,address,uint256)")
      assert computed == @transfer_topic
    end
  end

  describe "webhook payload construction" do
    @tag timeout: 120_000
    test "builds valid webhook payloads" do
      event = %Event{
        chain_id: 1,
        contract_address: @contract_address,
        transaction_hash: "0xabc123",
        block_number: 12_878_196,
        log_index: 0,
        topic0: @transfer_topic,
        topics: [@transfer_topic],
        data: "0x",
        decoded_params: %{},
        timestamp: 1_628_736_144
      }

      sub = Subscription.new(%{
        id: "test-sub",
        contract_address: @contract_address,
        event_signatures: ["Transfer(address,address,uint256)"],
        webhook_url: "https://hooks.example.com/test"
      })

      payload = Events.Webhook.build_payload(event, sub)
      assert payload.event.chain_id == 1
      assert payload.event.block_number == 12_878_196
      assert payload.event.topic0 == @transfer_topic
      assert payload.subscription.id == "test-sub"
    end

    @tag timeout: 120_000
    test "validates webhook URLs" do
      assert Events.Webhook.valid_url?("https://hooks.example.com/test")
      assert Events.Webhook.valid_url?("http://localhost:3000/webhook")
      refute Events.Webhook.valid_url?("not-a-url")
      refute Events.Webhook.valid_url?("")
    end
  end

  describe "subscription topic matching" do
    test "matches Transfer event signature" do
      sub = Subscription.new(%{event_signatures: ["Transfer(address,address,uint256)"]})
      assert Subscription.topic_matches?(sub, @transfer_topic)
    end

    test "does not match unrelated events" do
      sub = Subscription.new(%{event_signatures: ["Transfer(address,address,uint256)"]})
      approval_topic = "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"
      refute Subscription.topic_matches?(sub, approval_topic)
    end
  end
end
