defmodule Lux.Rust.TestRunnerTest do
  use ExUnit.Case, async: true

  alias Lux.Rust.TestRunner
  alias Lux.Rust.TestRunner.Summary

  describe "parse_test_summary/1" do
    test "correctly parses successful test summary output" do
      output = """
      running 4 tests
      test tests::test_prism_execution ... ok
      test tests::test_error_handling ... ok
      test tests::test_input_validation ... ok
      test tests::test_edge_case ... ok

      test result: ok. 4 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.05s
      """

      assert {:ok, %Summary{} = summary} = TestRunner.parse_test_summary(output)
      assert summary.status == :ok
      assert summary.passed == 4
      assert summary.failed == 0
      assert summary.ignored == 0
    end

    test "correctly parses failed test summary output" do
      output = """
      running 3 tests
      test tests::test_one ... ok
      test tests::test_two ... FAILED
      test tests::test_three ... ok

      test result: FAILED. 2 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.02s
      """

      assert {:ok, %Summary{} = summary} = TestRunner.parse_test_summary(output)
      assert summary.status == :failed
      assert summary.passed == 2
      assert summary.failed == 1
    end

    test "returns error when summary line is absent" do
      assert {:error, :summary_not_found} = TestRunner.parse_test_summary("compilation error: mismatched types")
    end
  end

  describe "generate_test_fixture/2" do
    test "generates valid Rust test harness code" do
      test_cases = [
        {"success_case", ~s({"x": 10, "y": 20}), ~s({"sum": 30})},
        {"zero_case", ~s({"x": 0, "y": 0}), ~s({"sum": 0})}
      ]

      fixture = TestRunner.generate_test_fixture("AddPrism", test_cases)

      assert String.contains?(fixture, "#[cfg(test)]")
      assert String.contains?(fixture, "mod tests {")
      assert String.contains?(fixture, "fn test_success_case()")
      assert String.contains?(fixture, "fn test_zero_case()")
      assert String.contains?(fixture, "AddPrism::run(&input)")
    end
  end
end
