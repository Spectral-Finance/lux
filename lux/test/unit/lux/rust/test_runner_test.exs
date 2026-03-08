defmodule Lux.Rust.TestRunnerTest do
  use ExUnit.Case, async: true
  import Lux.Rust.TestRunner

  @moduletag :unit

  describe "rust_available?/0" do
    test "detects Rust toolchain" do
      assert rust_available?() == true
    end
  end

  describe "run_cargo_test/1" do
    test "runs all Rust tests" do
      {output, code} = run_cargo_test()
      assert code == 0, "Rust tests failed:\n#{output}"
      assert output =~ "test result: ok"
    end
  end

  describe "assert_rust_tests_pass/0" do
    test "succeeds when all Rust tests pass" do
      assert {:ok, _output} = assert_rust_tests_pass()
    end
  end

  describe "assert_rust_test_pass/1" do
    test "runs specific test" do
      assert {:ok, _output} = assert_rust_test_pass("test_validate_string")
    end
  end

  describe "parse_results/1" do
    test "parses cargo test output" do
      output = """
      running 3 tests
      test types::tests::test_validate_string ... ok
      test types::tests::test_validate_integer ... ok
      test schema::tests::test_validate_list ... FAILED

      test result: FAILED. 2 passed; 1 failed; 0 ignored
      """

      result = parse_results(output)
      assert result.passed == 2
      assert result.failed == 1
      assert length(result.tests) == 3
    end

    test "handles all passing" do
      output = """
      running 2 tests
      test types::tests::test_validate_string ... ok
      test types::tests::test_validate_integer ... ok

      test result: ok. 2 passed; 0 failed; 0 ignored
      """

      result = parse_results(output)
      assert result.passed == 2
      assert result.failed == 0
    end
  end
end
