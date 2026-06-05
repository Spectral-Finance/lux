defmodule Lux.Rust.TestTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.Test

  describe "run_tests/2" do
    test "runs a simple unit test suite successfully" do
      suite = %{
        type: "unit",
        name: "math_suite",
        tests: [
          %{name: "addition", fn: fn -> 1 + 1 == 2 end},
          %{name: "subtraction", fn: fn -> 3 - 1 == 2 end}
        ]
      }

      assert {:ok, result} = Test.run_tests(suite)
      assert result.passed == 2
      assert result.failed == 0
      assert result.total == 2
    end

    test "reports failures correctly" do
      suite = %{
        type: "unit",
        name: "fail_suite",
        tests: [
          %{name: "will_pass", fn: fn -> true end},
          %{name: "will_fail", fn: fn -> false end}
        ]
      }

      assert {:ok, result} = Test.run_tests(suite)
      assert result.passed == 1
      assert result.failed == 1
      assert result.total == 2
      assert length(result.failures) == 1
    end

    test "reports unknown test type" do
      suite = %{type: "unknown", tests: []}
      assert {:error, "Unknown test type: unknown"} = Test.run_tests(suite)
    end
  end

  describe "run_unit_tests/2" do
    test "handles empty test list" do
      suite = %{type: "unit", tests: []}
      assert {:ok, result} = Test.run_unit_tests(suite)
      assert result.passed == 0
      assert result.failed == 0
    end

    test "handles test timeouts" do
      suite = %{
        type: "unit",
        tests: [
          %{
            name: "slow_test",
            fn: fn ->
              :timer.sleep(100)
              true
            end
          }
        ]
      }

      config = %{timeout: 10}
      assert {:ok, result} = Test.run_unit_tests(suite, config)
      assert result.passed == 0
      assert result.failed == 1
    end
  end

  describe "run_benchmarks/2" do
    test "runs benchmarks and returns timing data" do
      suite = %{
        type: "benchmark",
        tests: [
          %{
            name: "fast_math",
            fn: fn -> Enum.sum(1..100) end
          }
        ]
      }

      assert {:ok, result} = Test.run_benchmarks(suite, %{iterations: 10, warmup: 2})
      assert length(result.benchmarks) == 1
      benchmark = hd(result.benchmarks)
      assert benchmark.name == "fast_math"
      assert benchmark.iterations == 10
      assert benchmark.total_time_us > 0
      assert benchmark.avg_time_us > 0
      assert benchmark.ops_per_sec > 0
    end
  end

  describe "run_integration_tests/2" do
    test "runs integration tests with setup and teardown" do
      test_pid = self()

      suite = %{
        type: "integration",
        tests: [
          %{name: "integration_test", fn: fn -> true end}
        ]
      }

      config = %{
        setup: fn -> send(test_pid, :setup_called); :ok end,
        teardown: fn -> send(test_pid, :teardown_called); :ok end
      }

      assert {:ok, result} = Test.run_integration_tests(suite, config)
      assert result.passed == 1
      assert_received :setup_called
      assert_received :teardown_called
    end
  end
end
