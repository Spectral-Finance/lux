defmodule Lux.Web3.EventMonitorTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.EventMonitor
  alias Lux.Web3.EventMonitor.{Event, Matcher, Store, Subscription, SyncPlan, WebhookNotifier}

  @address "0x1111111111111111111111111111111111111111"
  @other_address "0x2222222222222222222222222222222222222222"
  @transfer_topic "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  @approval_topic "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"

  test "builds normalized subscriptions with deterministic ids" do
    assert {:ok, subscription} =
             Subscription.new(
               chain_id: "1",
               contract_address: String.upcase(@address),
               event_name: "Transfer",
               topics: [String.upcase(@transfer_topic), nil],
               from_block: "10",
               to_block: "20"
             )

    assert subscription.chain_id == 1
    assert subscription.contract_address == @address
    assert subscription.topics == [@transfer_topic, nil]
    assert subscription.from_block == 10
    assert subscription.to_block == 20
    assert String.starts_with?(subscription.id, "contract-events-")
  end

  test "rejects invalid subscriptions before any RPC work is attempted" do
    assert {:error, "contract_address must be a hex Ethereum address"} =
             Subscription.new(chain_id: 1, contract_address: "bad", topics: [])

    assert {:error, "from_block cannot be greater than to_block"} =
             Subscription.new(chain_id: 1, contract_address: @address, from_block: 12, to_block: 10)
  end

  test "normalizes JSON-RPC logs into event structs" do
    assert {:ok, event} =
             Event.from_log(
               %{
                 "address" => String.upcase(@address),
                 "blockNumber" => "0x10",
                 "transactionHash" => "0xABC",
                 "logIndex" => "0x2",
                 "topics" => [String.upcase(@transfer_topic)],
                 "data" => "0xDEADBEEF"
               },
               chain_id: 1
             )

    assert event.contract_address == @address
    assert event.block_number == 16
    assert event.log_index == 2
    assert event.transaction_hash == "0xabc"
    assert event.topics == [@transfer_topic]
    assert event.data == "0xdeadbeef"
  end

  test "matches subscriptions by chain, contract, block range, and topic filters" do
    subscription =
      subscription!(
        chain_id: 1,
        contract_address: @address,
        topics: [@transfer_topic, nil],
        from_block: 10
      )

    matching_event =
      event!(chain_id: 1, address: @address, topics: [@transfer_topic, @approval_topic], block: 11)

    wrong_address = event!(chain_id: 1, address: @other_address, topics: [@transfer_topic], block: 11)
    wrong_topic = event!(chain_id: 1, address: @address, topics: [@approval_topic], block: 11)
    too_early = event!(chain_id: 1, address: @address, topics: [@transfer_topic], block: 9)

    assert Matcher.match?(subscription, matching_event)
    refute Matcher.match?(subscription, wrong_address)
    refute Matcher.match?(subscription, wrong_topic)
    refute Matcher.match?(subscription, too_early)
  end

  test "plans bounded historical sync ranges" do
    subscription = subscription!(chain_id: 1, contract_address: @address, from_block: 10, to_block: 25)

    assert SyncPlan.ranges(subscription, 100, 7) == [
             %{from_block: 10, to_block: 16},
             %{from_block: 17, to_block: 23},
             %{from_block: 24, to_block: 25}
           ]
  end

  test "deduplicates, filters, and replays stored events" do
    {:ok, store} = Store.start_link([])
    first =
      event!(chain_id: 1, address: @address, block: 10)
      |> struct(subscription_id: "sub-a", log_index: 0)

    duplicate = %Event{first | decoded: %{amount: "latest"}}

    second =
      event!(chain_id: 1, address: @address, block: 11)
      |> struct(subscription_id: "sub-b", log_index: 1)

    Store.put_many(store, [first, duplicate, second])

    assert Store.replay(store, "sub-a") == [duplicate]
    assert Store.list(store, from_block: 11) == [second]
  end

  test "ingests matching logs, persists them, and emits webhook payloads" do
    {:ok, store} = Store.start_link([])
    parent = self()

    subscription =
      subscription!(
        id: "sub-transfer",
        chain_id: 1,
        contract_address: @address,
        topics: [@transfer_topic],
        webhook_url: "https://example.test/hooks/lux"
      )

    request_fun = fn url, body, opts ->
      send(parent, {:webhook, url, body, opts})
      {:ok, :sent}
    end

    assert {:ok, [%Event{subscription_id: "sub-transfer"} = event]} =
             EventMonitor.ingest_log(log(@address, 12, [@transfer_topic]), [subscription],
               chain_id: 1,
               store: store,
               webhook_secret: "secret",
               request_fun: request_fun
             )

    assert Store.replay(store, "sub-transfer") == [event]

    assert_receive {:webhook, "https://example.test/hooks/lux", payload, opts}
    assert payload.subscription_id == "sub-transfer"

    assert Enum.any?(Keyword.fetch!(opts, :headers), fn {key, _value} ->
             key == "x-lux-event-signature"
           end)
  end

  test "webhook payloads expose the complete replayable event identity" do
    event =
      event!(chain_id: 1, address: @address, block: 15)
      |> struct(subscription_id: "sub-a", log_index: 3)

    assert %{
             subscription_id: "sub-a",
             chain_id: 1,
             contract_address: @address,
             block_number: 15,
             transaction_hash: "0xabc",
             log_index: 3,
             topics: [@transfer_topic]
           } = WebhookNotifier.payload(event)
  end

  defp subscription!(attrs) do
    {:ok, subscription} = Subscription.new(attrs)
    subscription
  end

  defp event!(attrs) do
    {:ok, event} =
      attrs
      |> log()
      |> Event.from_log(chain_id: attrs[:chain_id])

    event
  end

  defp log(attrs) do
    log(attrs[:address], attrs[:block], Keyword.get(attrs, :topics, [@transfer_topic]))
  end

  defp log(address, block, topics) do
    %{
      "address" => address,
      "blockNumber" => "0x" <> Integer.to_string(block, 16),
      "transactionHash" => "0xABC",
      "logIndex" => "0x0",
      "topics" => topics,
      "data" => "0x"
    }
  end
end
