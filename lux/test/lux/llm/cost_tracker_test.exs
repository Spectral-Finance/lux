defmodule Lux.LLM.CostTrackerTest do
  use ExUnit.Case, async: false

  alias Lux.LLM.CostTracker

  setup do
    {:ok, pid} = CostTracker.start_link(name: :test_cost_tracker)
    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    %{server: :test_cost_tracker}
  end

  describe "record/3" do
    test "records usage and accumulates totals", %{server: s} do
      :ok = CostTracker.record(:openai, %{input_tokens: 100, output_tokens: 50, cost: 0.003}, s)
      Process.sleep(10)
      {:ok, totals} = CostTracker.get_totals(:openai, s)
      assert totals.input_tokens == 100
      assert totals.output_tokens == 50
      assert totals.total_cost == 0.003
      assert totals.call_count == 1
    end

    test "accumulates across multiple calls", %{server: s} do
      CostTracker.record(:openai, %{input_tokens: 100, output_tokens: 50, cost: 0.003}, s)
      CostTracker.record(:openai, %{input_tokens: 200, output_tokens: 100, cost: 0.006}, s)
      Process.sleep(10)
      {:ok, totals} = CostTracker.get_totals(:openai, s)
      assert totals.input_tokens == 300
      assert totals.total_cost == 0.009
      assert totals.call_count == 2
    end
  end

  describe "get_totals/2" do
    test "returns error for untracked provider", %{server: s} do
      assert {:error, :not_found} = CostTracker.get_totals(:unknown, s)
    end
  end

  describe "get_all_totals/1" do
    test "returns map of all provider totals", %{server: s} do
      CostTracker.record(:openai, %{input_tokens: 10, output_tokens: 5, cost: 0.001}, s)
      CostTracker.record(:anthropic, %{input_tokens: 20, output_tokens: 10, cost: 0.002}, s)
      Process.sleep(10)
      {:ok, all} = CostTracker.get_all_totals(s)
      assert Map.has_key?(all, :openai)
      assert Map.has_key?(all, :anthropic)
    end
  end

  describe "reset/2" do
    test "resets totals to zero", %{server: s} do
      CostTracker.record(:openai, %{input_tokens: 100, output_tokens: 50, cost: 0.003}, s)
      Process.sleep(10)
      CostTracker.reset(:openai, s)
      Process.sleep(10)
      {:ok, totals} = CostTracker.get_totals(:openai, s)
      assert totals.call_count == 0
      assert totals.total_cost == 0.0
    end
  end
end
