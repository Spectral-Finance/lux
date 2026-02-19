defmodule Lux.LLM.CostTrackerTest do
  use UnitCase, async: false

  alias Lux.LLM.CostTracker

  setup do
    CostTracker.reset()
    :ok
  end

  describe "record/3 and summary/1" do
    test "records and summarizes a single request" do
      CostTracker.record(:openai, "gpt-4o", %{
        input_tokens: 100,
        output_tokens: 50,
        cost: 0.005
      })

      summary = CostTracker.summary()

      assert summary.total_requests == 1
      assert summary.total_input_tokens == 100
      assert summary.total_output_tokens == 50
      assert_in_delta summary.total_cost, 0.005, 0.0001
    end

    test "accumulates multiple requests" do
      CostTracker.record(:openai, "gpt-4o", %{
        input_tokens: 100,
        output_tokens: 50,
        cost: 0.005
      })

      CostTracker.record(:anthropic, "claude-3-opus-20240229", %{
        input_tokens: 200,
        output_tokens: 100,
        cost: 0.01
      })

      CostTracker.record(:openai, "gpt-4o-mini", %{
        input_tokens: 500,
        output_tokens: 200,
        cost: 0.001
      })

      summary = CostTracker.summary()

      assert summary.total_requests == 3
      assert summary.total_input_tokens == 800
      assert summary.total_output_tokens == 350
      assert_in_delta summary.total_cost, 0.016, 0.0001
    end

    test "groups by provider" do
      CostTracker.record(:openai, "gpt-4o", %{input_tokens: 100, output_tokens: 50, cost: 0.005})

      CostTracker.record(:openai, "gpt-4o", %{
        input_tokens: 200,
        output_tokens: 100,
        cost: 0.01
      })

      CostTracker.record(:anthropic, "claude", %{
        input_tokens: 300,
        output_tokens: 150,
        cost: 0.02
      })

      summary = CostTracker.summary()

      assert Map.has_key?(summary.by_provider, :openai)
      assert Map.has_key?(summary.by_provider, :anthropic)
      assert summary.by_provider[:openai].requests == 2
      assert summary.by_provider[:anthropic].requests == 1
    end

    test "groups by model" do
      CostTracker.record(:openai, "gpt-4o", %{input_tokens: 100, output_tokens: 50, cost: 0.005})

      CostTracker.record(:openai, "gpt-4o-mini", %{
        input_tokens: 200,
        output_tokens: 100,
        cost: 0.001
      })

      summary = CostTracker.summary()

      assert Map.has_key?(summary.by_model, "gpt-4o")
      assert Map.has_key?(summary.by_model, "gpt-4o-mini")
    end
  end

  describe "by_provider/1" do
    test "filters by provider" do
      CostTracker.record(:openai, "gpt-4o", %{input_tokens: 100, output_tokens: 50, cost: 0.005})

      CostTracker.record(:anthropic, "claude", %{
        input_tokens: 200,
        output_tokens: 100,
        cost: 0.01
      })

      openai_costs = CostTracker.by_provider(:openai)

      assert openai_costs.total_requests == 1
      assert openai_costs.total_input_tokens == 100
      assert_in_delta openai_costs.total_cost, 0.005, 0.0001
    end
  end

  describe "summary with :since filter" do
    test "filters by timestamp" do
      CostTracker.record(:openai, "gpt-4o", %{input_tokens: 100, output_tokens: 50, cost: 0.005})

      # Wait to ensure a different timestamp
      Process.sleep(20)

      # Get the current time after the first record
      now = System.system_time(:millisecond)

      # Record after the time marker
      Process.sleep(10)

      CostTracker.record(:openai, "gpt-4o", %{
        input_tokens: 200,
        output_tokens: 100,
        cost: 0.01
      })

      # Summary since "now" should only include the second record
      summary = CostTracker.summary(since: now)

      assert summary.total_requests == 1
      assert summary.total_input_tokens == 200
    end
  end

  describe "reset/0" do
    test "clears all data" do
      CostTracker.record(:openai, "gpt-4o", %{input_tokens: 100, output_tokens: 50, cost: 0.005})

      CostTracker.reset()

      summary = CostTracker.summary()
      assert summary.total_requests == 0
      assert summary.total_cost == 0.0
    end
  end
end
