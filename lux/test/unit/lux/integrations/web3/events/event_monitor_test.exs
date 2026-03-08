defmodule Lux.Integrations.Web3.Events.EventMonitorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Events.EventMonitor

  test "starts and reports status" do
    {:ok, pid} = EventMonitor.start_link(
      chain: :ethereum, rpc_url: "https://test",
      poll_interval_ms: 100_000, auto_start: false, name: :"test_#{:rand.uniform(1_000_000)}"
    )

    status = EventMonitor.status(pid)
    assert status.chain == :ethereum
    assert status.watches == 0
    assert status.events_stored == 0
  end

  test "add and remove watches" do
    {:ok, pid} = EventMonitor.start_link(
      chain: :ethereum, rpc_url: "https://test",
      poll_interval_ms: 100_000, auto_start: false, name: :"test_#{:rand.uniform(1_000_000)}"
    )

    {:ok, id} = EventMonitor.add_watch(pid, %{address: "0xcontract"})
    assert EventMonitor.status(pid).watches == 1

    :ok = EventMonitor.remove_watch(pid, id)
    assert EventMonitor.status(pid).watches == 0
  end

  test "remove unknown watch returns error" do
    {:ok, pid} = EventMonitor.start_link(
      chain: :ethereum, rpc_url: "https://test",
      auto_start: false, name: :"test_#{:rand.uniform(1_000_000)}"
    )

    assert {:error, :not_found} = EventMonitor.remove_watch(pid, 999)
  end

  test "get_events returns empty initially" do
    {:ok, pid} = EventMonitor.start_link(
      chain: :ethereum, rpc_url: "https://test",
      auto_start: false, name: :"test_#{:rand.uniform(1_000_000)}"
    )

    assert {:ok, []} = EventMonitor.get_events(pid)
  end
end
