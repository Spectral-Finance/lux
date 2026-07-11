defmodule Lux.RustTestRunnerTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  doctest Lux.RustTestRunner

  describe "test_utils" do
    test "returns expected utility function names" do
      utils = Lux.RustTestRunner.test_utils()
      assert :assert_exit_code_zero in utils
      assert :assert_test_output_contains in utils
      assert :assert_no_failures in utils
    end
  end

  describe "resolve_cargo_project_path" do
    test "finds Cargo.toml in lux/rust/" do
      assert {:ok, path} = Lux.RustTestRunner.resolve_cargo_project_path()
      assert path |> String.ends_with?("rust")
      assert File.exists?(Path.join(path, "Cargo.toml"))
    end
  end

  describe "assert_exit_code_zero" do
    test "returns true for zero failures" do
      result = {:ok, %{tests_failed: 0, tests_passed: 42}}
      assert Lux.RustTestRunner.assert_exit_code_zero(result) == true
    end

    test "returns false for non-zero failures" do
      result = {:ok, %{tests_failed: 3, tests_passed: 7}}
      assert Lux.RustTestRunner.assert_exit_code_zero(result) == false
    end

    test "returns false for error tuple" do
      result = {:error, "some error"}
      assert Lux.RustTestRunner.assert_exit_code_zero(result) == false
    end
  end

  describe "assert_test_output_contains" do
    test "returns true when output contains expected string and exit is zero" do
      result = {"test result: ok. 42 passed", 0, "42 passed"}
      assert Lux.RustTestRunner.assert_test_output_contains(result) == true
    end

    test "returns false when output does not contain expected string" do
      result = {"test result: ok. 42 passed", 0, "missing"}
      assert Lux.RustTestRunner.assert_test_output_contains(result) == false
    end

    test "returns false when exit code is non-zero" do
      result = {"test result: FAILED. 7 passed", 1, "7 passed"}
      assert Lux.RustTestRunner.assert_test_output_contains(result) == false
    end
  end

  describe "assert_no_failures" do
    test "returns true when tests passed and failures are zero" do
      result = {:ok, %{tests_failed: 0, tests_passed: 10}}
      assert Lux.RustTestRunner.assert_no_failures(result) == true
    end

    test "returns false when failures are non-zero" do
      result = {:ok, %{tests_failed: 2, tests_passed: 10}}
      assert Lux.RustTestRunner.assert_no_failures(result) == false
    end

    test "returns false when no tests ran (passed is zero)" do
      result = {:ok, %{tests_failed: 0, tests_passed: 0}}
      assert Lux.RustTestRunner.assert_no_failures(result) == false
    end

    test "returns false for error tuple" do
      result = {:error, "cargo not found"}
      assert Lux.RustTestRunner.assert_no_failures(result) == false
    end
  end

  describe "create_fixture / load_fixture" do
    test "create_fixture returns {:ok, path} on success" do
      result = Lux.RustTestRunner.create_fixture("test_fixture", %{name: "test", value: 42})
      assert {:ok, path} = result
      assert File.exists?(path)
      File.rm(path)
    end

    test "create_fixture function is callable" do
      assert is_function(&Lux.RustTestRunner.create_fixture/2, 2)
    end

    test "load_fixture returns {:ok, data} for existing fixture" do
      Lux.RustTestRunner.create_fixture("test_load_fixture", %{key: "val"})
      assert {:ok, %{key: "val"}} = Lux.RustTestRunner.load_fixture("test_load_fixture")
      # Clean up
      fixture_file = Path.join([:code.priv_dir(:lux), "rust_test_fixtures", "test_load_fixture.json"])
      if File.exists?(fixture_file), do: File.rm(fixture_file)
    end

    test "load_fixture returns {:error, _} for non-existent fixture" do
      assert {:error, _} = Lux.RustTestRunner.load_fixture("nonexistent_fixture_xyz")
    end
  end

  describe "summary" do
    test "returns correct summary from results" do
      results = %{tests_passed: 10, tests_failed: 2, duration: "1.5s"}
      summary = Lux.RustTestRunner.summary(results)
      assert summary.total == 12
      assert summary.passed == 10
      assert summary.failed == 2
      assert summary.duration == "1.5s"
    end
  end

  describe "parse_cargo_output" do
    test "parses standard cargo test success output" do
      output = """
      running 42 tests
      test result: ok. 42 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.12s
      """

      assert {:ok, result} = Lux.RustTestRunner.parse_cargo_output(output)
      assert result.tests_passed == 42
      assert result.tests_failed == 0
      assert result.duration == "0.12"
    end

    test "parses cargo test with failures" do
      output = """
      running 10 tests
      test result: FAILED. 7 passed; 3 failed; 0 ignored; 0 measured; 0 filtered out; finished in 1.23s
      """

      assert {:ok, result} = Lux.RustTestRunner.parse_cargo_output(output)
      assert result.tests_passed == 7
      assert result.tests_failed == 3
      assert result.duration == "1.23"
    end

    test "handles empty output with error" do
      assert {:error, reason} = Lux.RustTestRunner.parse_cargo_output("")
      assert reason =~ "Empty"
    end

    test "handles unrecognizable output with error" do
      assert {:error, _} = Lux.RustTestRunner.parse_cargo_output("garbage output")
    end

    test "aggregates multiple test result lines" do
      output = """
      running 10 tests
      test result: ok. 8 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.10s

      running 5 tests
      test result: ok. 5 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.05s
      """

      assert {:ok, result} = Lux.RustTestRunner.parse_cargo_output(output)
      assert result.tests_passed == 13
      assert result.tests_failed == 0
    end

    test "fails on 0 passed and 0 failed" do
      output = "running 0 tests\n"
      assert {:error, _} = Lux.RustTestRunner.parse_cargo_output(output)
    end
  end

  describe "parse_coverage_output" do
    test "parses tarpaulin coverage percentage with decimal" do
      output = """
      [tarpaulin] Coverage Results:
      Coverage : 85.7% (120/140 lines)
      """

      assert {:ok, result} = Lux.RustTestRunner.parse_coverage_output(output)
      assert result.coverage_percentage == 85.7
    end

    test "parses tarpaulin coverage percentage as integer" do
      output = """
      [tarpaulin] Coverage Results:
      Coverage : 85% (120/140 lines)
      """

      assert {:ok, result} = Lux.RustTestRunner.parse_coverage_output(output)
      assert result.coverage_percentage == 85.0
    end

    test "handles missing coverage data with error" do
      assert {:error, _} = Lux.RustTestRunner.parse_coverage_output("")
    end
  end
end
