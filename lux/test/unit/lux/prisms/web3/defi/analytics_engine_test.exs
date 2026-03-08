defmodule Lux.Prisms.Web3.DeFi.AnalyticsEngineTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.DeFi.AnalyticsEngine

  setup do
    name = :"defi_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = AnalyticsEngine.start_link(name: name)
    %{pid: pid}
  end

  test "track protocol", %{pid: pid} do
    {:ok, p} = AnalyticsEngine.track_protocol(pid, %{name: "Aave", tvl: 10_000_000_000, apy: 5.2, audited: true})
    assert p.name == "Aave"
    assert p.audited
  end

  test "track missing name", %{pid: pid} do
    assert {:error, :missing_name} = AnalyticsEngine.track_protocol(pid, %{tvl: 100})
  end

  test "track negative tvl", %{pid: pid} do
    assert {:error, :invalid_tvl} = AnalyticsEngine.track_protocol(pid, %{name: "Bad", tvl: -1})
  end

  test "update tvl with snapshot", %{pid: pid} do
    {:ok, _} = AnalyticsEngine.track_protocol(pid, %{id: "aave", name: "Aave", tvl: 10_000_000_000})
    {:ok, updated} = AnalyticsEngine.update_tvl(pid, "aave", 11_000_000_000)
    assert updated.tvl == 11_000_000_000
  end

  test "update tvl not found", %{pid: pid} do
    assert {:error, :not_found} = AnalyticsEngine.update_tvl(pid, "nope", 100)
  end

  test "update tvl negative", %{pid: pid} do
    {:ok, _} = AnalyticsEngine.track_protocol(pid, %{id: "aave", name: "Aave"})
    assert {:error, :invalid_tvl} = AnalyticsEngine.update_tvl(pid, "aave", -1)
  end

  test "list protocols", %{pid: pid} do
    {:ok, _} = AnalyticsEngine.track_protocol(pid, %{name: "Aave"})
    {:ok, _} = AnalyticsEngine.track_protocol(pid, %{name: "Compound"})
    {:ok, list} = AnalyticsEngine.list_protocols(pid)
    assert length(list) == 2
  end

  test "get not found", %{pid: pid} do
    assert {:error, :not_found} = AnalyticsEngine.get_protocol(pid, "nope")
  end

  test "portfolio add and summary", %{pid: pid} do
    {:ok, _} = AnalyticsEngine.add_to_portfolio(pid, %{protocol: "Aave", amount: 10000, apy: 5.0})
    {:ok, _} = AnalyticsEngine.add_to_portfolio(pid, %{protocol: "Compound", amount: 5000, apy: 3.0})
    {:ok, summary} = AnalyticsEngine.portfolio_summary(pid)
    assert summary.total_value == 15000
    assert summary.positions == 2
    assert summary.weighted_apy > 3
    assert summary.daily_yield > 0
  end

  test "portfolio add missing protocol", %{pid: pid} do
    assert {:error, :missing_protocol} = AnalyticsEngine.add_to_portfolio(pid, %{amount: 100})
  end

  test "portfolio add negative amount", %{pid: pid} do
    assert {:error, :invalid_amount} = AnalyticsEngine.add_to_portfolio(pid, %{protocol: "Aave", amount: -100})
  end

  test "portfolio empty summary", %{pid: pid} do
    {:ok, summary} = AnalyticsEngine.portfolio_summary(pid)
    assert summary.total_value == 0
    assert summary.positions == 0
  end

  test "compare yields" do
    protocols = [%{name: "Aave", apy: 5}, %{name: "Compound", apy: 3}, %{name: "Curve", apy: 8}]
    {:ok, r} = AnalyticsEngine.compare_yields(protocols)
    assert r.best == "Curve"
    assert length(r.ranked) == 3
  end

  test "compare yields empty" do
    assert {:error, :empty_list} = AnalyticsEngine.compare_yields([])
  end

  test "risk score safe protocol" do
    {:ok, r} = AnalyticsEngine.risk_score(%{audited: true, tvl: 500_000_000, age_days: 500, apy: 5})
    assert r.level == :low
    assert r.score < 30
  end

  test "risk score risky protocol" do
    {:ok, r} = AnalyticsEngine.risk_score(%{audited: false, tvl: 100_000, age_days: 10, apy: 200})
    assert r.level == :high
    assert r.score >= 60
  end

  test "risk score medium protocol" do
    {:ok, r} = AnalyticsEngine.risk_score(%{audited: true, tvl: 5_000_000, age_days: 200, apy: 50})
    assert r.level == :medium
  end
end
