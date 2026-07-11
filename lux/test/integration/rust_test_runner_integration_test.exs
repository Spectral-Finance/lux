defmodule Lux.RustTestRunnerIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :rust_integration

  setup do
    if System.find_executable("cargo") do
      {:ok, cargo_available: true}
    else
      {:skip, "cargo not available"}
    end
  end

  describe "RustTestRunner integration with real Cargo project" do
    test "resolve_cargo_project_path finds the Rust crate", %{cargo_available: true} do
      assert {:ok, path} = Lux.RustTestRunner.resolve_cargo_project_path()
      assert File.exists?(Path.join(path, "Cargo.toml"))
    end

    test "runs Rust tests via cargo and returns parsed results", %{cargo_available: true} do
      assert {:ok, results} = Lux.RustTestRunner.run()
      assert results.tests_passed > 0
      assert results.tests_failed == 0
    end

    test "assert_no_failures returns true for passing results" do
      assert Lux.RustTestRunner.assert_no_failures({:ok, %{tests_failed: 0, tests_passed: 5}}) == true
    end

    test "assert_no_failures returns false for zero tests" do
      assert Lux.RustTestRunner.assert_no_failures({:ok, %{tests_failed: 0, tests_passed: 0}}) == false
    end

    test "assert_no_failures returns false for failures" do
      assert Lux.RustTestRunner.assert_no_failures({:ok, %{tests_failed: 1, tests_passed: 5}}) == false
    end

    test "assert_no_failures returns false for error tuples" do
      assert Lux.RustTestRunner.assert_no_failures({:error, "cargo not found"}) == false
    end
  end
end
