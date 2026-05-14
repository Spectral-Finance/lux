defmodule Lux.Rust.TestRunnerTest do
  use UnitCase, async: false

  alias Lux.Rust.TestFixtures
  alias Lux.Rust.TestRunner

  test "parses cargo test output" do
    output = "test result: ok. 3 passed; 0 failed; 1 ignored; 0 measured; 2 filtered out;"

    result = TestRunner.parse_results(output)

    assert result.status == :ok
    assert result.passed == 3
    assert result.failed == 0
    assert result.ignored == 1
    assert result.filtered_out == 2
  end

  test "runs cargo tests for a temporary Rust project" do
    TestFixtures.with_temp_project(fn project_path ->
      assert {:ok, result} = TestRunner.run(project_path: project_path)
      assert result.status == :ok
      assert result.passed == 1
      assert result.failed == 0
      assert result.command == ["cargo", "test"]
    end)
  end

  test "supports cargo test filters" do
    TestFixtures.with_temp_project(fn project_path ->
      assert {:ok, result} =
               TestRunner.run(project_path: project_path, filter: "adds_two_numbers")

      assert result.passed == 1
      assert result.command == ["cargo", "test", "adds_two_numbers"]
    end)
  end

  test "returns an error for missing Cargo.toml" do
    assert {:error, reason} = TestRunner.run(project_path: System.tmp_dir!())
    assert reason =~ "No Cargo.toml"
  end

  test "builds a coverage command plan" do
    plan = TestRunner.coverage_plan(project_path: "priv/rust", output: "cover/rust/lcov.info")

    assert plan.project_path =~ "priv/rust"
    assert {"CARGO_INCREMENTAL", "0"} in plan.env
    assert ["grcov", "." | _] = plan.command
  end
end
