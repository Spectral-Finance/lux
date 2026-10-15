defmodule Lux.Rust.TestRunnerTest do
  use ExUnit.Case, async: true
  alias Lux.Rust.TestRunner

  test "parses cargo test execution output into structured ExUnit metrics" do
    sample = "running 4 tests\ntest result: ok. 4 passed; 0 failed; 1 ignored; 0 measured"
    {:ok, summary} = TestRunner.parse_cargo_test_output(sample)

    assert summary.status == :passed
    assert summary.passed == 4
    assert summary.failed == 0
    assert summary.total == 5
  end
end
