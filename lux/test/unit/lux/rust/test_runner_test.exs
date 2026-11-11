defmodule Lux.Rust.TestRunnerTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.TestRunner

  test "parses cargo test output and aggregates Rust coverage metrics" do
    sample = "running 4 tests\ntest result: ok. 4 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out"
    assert {:ok, %{status: :passed, passed: 4, failed: 0, ignored: 1}} =
             TestRunner.parse_cargo_test_output(sample)

    cov = TestRunner.summarize_coverage([%{lines_covered: 45, lines_total: 50}, %{lines_covered: 50, lines_total: 50}])
    assert cov.coverage_pct == 95.0
  end
end
