defmodule Lux.Integrations.Web3.Events.SubscriptionManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Events.SubscriptionManager

  setup do
    {:ok, pid} = SubscriptionManager.start_link(name: :"sub_mgr_#{:rand.uniform(1_000_000)}")
    %{pid: pid}
  end

  test "subscribe to contract events", %{pid: pid} do
    assert {:ok, sub} = SubscriptionManager.subscribe(pid, %{
      contract_address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
      chain: :ethereum,
      event_types: [:transfer]
    })

    assert sub.id == 1
    assert sub.active == true
    assert sub.chain == :ethereum
  end

  test "list subscriptions", %{pid: pid} do
    SubscriptionManager.subscribe(pid, %{contract_address: "0xaaa", chain: :ethereum})
    SubscriptionManager.subscribe(pid, %{contract_address: "0xbbb", chain: :polygon})

    subs = SubscriptionManager.list(pid)
    assert length(subs) == 2
  end

  test "unsubscribe", %{pid: pid} do
    {:ok, sub} = SubscriptionManager.subscribe(pid, %{contract_address: "0xaaa"})
    assert :ok = SubscriptionManager.unsubscribe(pid, sub.id)
    assert [] = SubscriptionManager.list(pid)
  end

  test "unsubscribe unknown returns error", %{pid: pid} do
    assert {:error, :not_found} = SubscriptionManager.unsubscribe(pid, 999)
  end

  test "filter by contract", %{pid: pid} do
    SubscriptionManager.subscribe(pid, %{contract_address: "0xAAA"})
    SubscriptionManager.subscribe(pid, %{contract_address: "0xBBB"})

    matches = SubscriptionManager.for_contract(pid, "0xaaa")
    assert length(matches) == 1
  end

  test "filter by chain", %{pid: pid} do
    SubscriptionManager.subscribe(pid, %{contract_address: "0xaaa", chain: :ethereum})
    SubscriptionManager.subscribe(pid, %{contract_address: "0xbbb", chain: :polygon})

    eth = SubscriptionManager.for_chain(pid, :ethereum)
    assert length(eth) == 1
    assert hd(eth).chain == :ethereum
  end
end
