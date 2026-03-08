defmodule Lux.Prisms.Twitter.Analytics.AlertSystemTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.Analytics.AlertSystem

  setup do
    name = :"alert_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = AlertSystem.start_link(name: name)
    %{pid: pid}
  end

  test "add and list alerts", %{pid: pid} do
    {:ok, alert} = AlertSystem.add_alert(pid, %{name: "Viral tweet", metric: :likes, threshold: 100})
    assert alert.name == "Viral tweet"
    {:ok, alerts} = AlertSystem.list_alerts(pid)
    assert length(alerts) == 1
  end

  test "check triggers matching alert", %{pid: pid} do
    {:ok, _} = AlertSystem.add_alert(pid, %{name: "High likes", metric: :likes, operator: :gte, threshold: 100})
    {:ok, triggered} = AlertSystem.check(pid, %{likes: 150})
    assert length(triggered) == 1
    assert hd(triggered).alert_name == "High likes"
    assert hd(triggered).value == 150
  end

  test "check does not trigger below threshold", %{pid: pid} do
    {:ok, _} = AlertSystem.add_alert(pid, %{metric: :likes, operator: :gte, threshold: 100})
    {:ok, triggered} = AlertSystem.check(pid, %{likes: 50})
    assert triggered == []
  end

  test "less than operator", %{pid: pid} do
    {:ok, _} = AlertSystem.add_alert(pid, %{name: "Low engagement", metric: :engagement, operator: :lt, threshold: 5})
    {:ok, triggered} = AlertSystem.check(pid, %{engagement: 2})
    assert length(triggered) == 1
  end

  test "remove alert", %{pid: pid} do
    {:ok, alert} = AlertSystem.add_alert(pid, %{metric: :likes, threshold: 10})
    :ok = AlertSystem.remove_alert(pid, alert.id)
    {:ok, alerts} = AlertSystem.list_alerts(pid)
    assert alerts == []
  end

  test "triggered history persists", %{pid: pid} do
    {:ok, _} = AlertSystem.add_alert(pid, %{metric: :likes, threshold: 10})
    {:ok, _} = AlertSystem.check(pid, %{likes: 20})
    {:ok, _} = AlertSystem.check(pid, %{likes: 30})
    {:ok, history} = AlertSystem.get_triggered(pid)
    assert length(history) >= 2
  end
end
