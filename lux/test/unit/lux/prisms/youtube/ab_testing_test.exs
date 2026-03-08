defmodule Lux.Prisms.YouTube.ABTestingTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.ABTesting

  setup do
    name = :"ab_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = ABTesting.start_link(name: name)
    %{pid: pid}
  end

  test "create experiment", %{pid: pid} do
    {:ok, exp} = ABTesting.create_experiment(pid, %{name: "Thumb test", variants: ["A", "B"], video_id: "v1"})
    assert exp.status == :running
    assert map_size(exp.variants) == 2
  end

  test "record impressions and clicks", %{pid: pid} do
    {:ok, exp} = ABTesting.create_experiment(pid, %{variants: ["A", "B"]})
    :ok = ABTesting.record_impression(pid, exp.id, "A")
    :ok = ABTesting.record_impression(pid, exp.id, "A")
    :ok = ABTesting.record_click(pid, exp.id, "A")
    {:ok, results} = ABTesting.get_results(pid, exp.id)
    assert results.variants["A"].impressions == 2
    assert results.variants["A"].clicks == 1
    assert results.variants["A"].ctr == 50.0
  end

  test "conclude picks winner", %{pid: pid} do
    {:ok, exp} = ABTesting.create_experiment(pid, %{variants: ["A", "B"]})
    for _ <- 1..100, do: ABTesting.record_impression(pid, exp.id, "A")
    for _ <- 1..100, do: ABTesting.record_impression(pid, exp.id, "B")
    for _ <- 1..30, do: ABTesting.record_click(pid, exp.id, "A")
    for _ <- 1..10, do: ABTesting.record_click(pid, exp.id, "B")
    {:ok, result} = ABTesting.conclude(pid, exp.id)
    assert result.winner == "A"
    assert result.experiment.status == :concluded
  end

  test "unknown variant returns error", %{pid: pid} do
    {:ok, exp} = ABTesting.create_experiment(pid, %{variants: ["A", "B"]})
    assert {:error, :unknown_variant} = ABTesting.record_click(pid, exp.id, "C")
  end

  test "list experiments", %{pid: pid} do
    {:ok, _} = ABTesting.create_experiment(pid, %{name: "Test 1"})
    {:ok, _} = ABTesting.create_experiment(pid, %{name: "Test 2"})
    {:ok, list} = ABTesting.list_experiments(pid)
    assert length(list) == 2
  end

  test "not found experiment", %{pid: pid} do
    assert {:error, :not_found} = ABTesting.get_results(pid, "nope")
  end
end
