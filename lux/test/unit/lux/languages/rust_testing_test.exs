defmodule Lux.Languages.RustTestingTest do
  use UnitAPICase, async: true

  alias Lux.Rust.Testing.Runner

  describe "Runner.parse_output/2" do
    test "parses Cargo test output correctly" do
      sample = """
      running 3 tests
      test tests::test_math_add ... ok
      test tests::test_math_fibonacci ... ok
      test tests::test_function_not_found ... ok

      test result: ok. 3 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out
      """

      report = Runner.parse_output(sample, true)
      assert report.passed == 3
      assert report.failed == 0
      assert report.ignored == 0
      assert report.success == true
      assert length(report.tests) == 3
    end

    test "parses test failures" do
      sample = """
      running 2 tests
      test tests::test_one ... ok
      test tests::test_two ... FAILED

      test result: FAILED. 1 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out
      """

      report = Runner.parse_output(sample, false)
      assert report.passed == 1
      assert report.failed == 1
      assert report.success == false
    end
  end

  describe "Runner.run_tests/1" do
    test "executes tests or returns simulated report" do
      assert {:ok, report} = Runner.run_tests()
      assert report.passed >= 1
      assert report.success == true
    end
  end
end
