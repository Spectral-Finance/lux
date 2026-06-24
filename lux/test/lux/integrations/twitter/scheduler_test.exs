defmodule Lux.Integrations.Twitter.SchedulerTest do
  use ExUnit.Case
  alias Lux.Integrations.Twitter.Scheduler
  alias Lux.Integrations.Twitter.Queue

  setup do
    start_supervised!(Queue)
    :ok
  end

  test "starts successfully without auto_start" do
    assert {:ok, _pid} = Scheduler.start_link(auto_start: false)
  end

  test "handles poll when queue is empty" do
    {:ok, state} = Scheduler.init(auto_start: false)
    assert {:noreply, _} = Scheduler.handle_info(:poll, state)
  end
end
