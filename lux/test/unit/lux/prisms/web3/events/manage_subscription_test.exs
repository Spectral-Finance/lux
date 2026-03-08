defmodule Lux.Prisms.Web3.Events.ManageSubscriptionTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Web3.Events.ManageSubscription
  alias Lux.Integrations.Web3.Events.SubscriptionManager

  setup do
    {:ok, pid} = SubscriptionManager.start_link(name: :"test_#{:rand.uniform(1_000_000)}")
    %{pid: pid}
  end

  test "subscribe via prism", %{pid: pid} do
    assert {:ok, result} = ManageSubscription.handler(
      %{action: "subscribe", contract_address: "0xUSDT", chain: :ethereum, pid: pid},
      []
    )
    assert result.subscription.contract_address == "0xUSDT"
  end

  test "list via prism", %{pid: pid} do
    ManageSubscription.handler(%{action: "subscribe", contract_address: "0xa", pid: pid}, [])
    ManageSubscription.handler(%{action: "subscribe", contract_address: "0xb", pid: pid}, [])

    assert {:ok, result} = ManageSubscription.handler(%{action: "list", pid: pid}, [])
    assert result.count == 2
  end

  test "unsubscribe via prism", %{pid: pid} do
    {:ok, sub_result} = ManageSubscription.handler(
      %{action: "subscribe", contract_address: "0xa", pid: pid}, []
    )

    assert {:ok, _} = ManageSubscription.handler(
      %{action: "unsubscribe", subscription_id: sub_result.subscription.id, pid: pid}, []
    )

    {:ok, list_result} = ManageSubscription.handler(%{action: "list", pid: pid}, [])
    assert list_result.count == 0
  end
end
