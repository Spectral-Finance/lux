defmodule Lux.Integrations.Web3.Chain.BlockMonitorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Chain.BlockMonitor

  setup do
    Req.Test.stub(Lux.Web3.MonitorMock, fn conn ->
      Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => "0xF4240"})
    end)
    :ok
  end

  test "starts and reports status" do
    {:ok, pid} = BlockMonitor.start_link(
      chain: :ethereum, rpc_url: "https://test",
      poll_interval_ms: 100_000, auto_start: false, name: nil
    )

    status = BlockMonitor.status(pid)
    assert status.chain == :ethereum
    assert status.subscribers == 0
    assert status.last_block == nil
  end

  test "subscribe and receive block notifications" do
    {:ok, pid} = BlockMonitor.start_link(
      chain: :ethereum, rpc_url: "https://test",
      poll_interval_ms: 100_000, auto_start: false, name: nil,
      plug: {Req.Test, Lux.Web3.MonitorMock}
    )

    # Allow the GenServer process to use the stub
    Req.Test.allow(Lux.Web3.MonitorMock, self(), pid)

    :ok = BlockMonitor.subscribe(pid, self())
    assert BlockMonitor.status(pid).subscribers == 1

    # Trigger poll
    send(pid, :poll)

    assert_receive {:new_block, :ethereum, 1_000_000}, 1000
    assert BlockMonitor.current_block(pid) == 1_000_000
  end

  test "unsubscribe stops notifications" do
    {:ok, pid} = BlockMonitor.start_link(
      chain: :ethereum, rpc_url: "https://test",
      poll_interval_ms: 100_000, auto_start: false, name: nil
    )

    :ok = BlockMonitor.subscribe(pid, self())
    :ok = BlockMonitor.unsubscribe(pid, self())
    assert BlockMonitor.status(pid).subscribers == 0
  end
end
